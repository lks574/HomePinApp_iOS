import PhotosUI
import SwiftUI

#if canImport(Vision)
import CoreGraphics
#endif

/// 영수증 스캔 어댑터 시트. 카메라(iOS, 가용 시)·사진 보관함에서 영수증 한 장을 받아 OCR 로
/// 품목 라인을 뽑아 호출부(`CaptureSheet`)의 칩 staging 으로 합류시킨다.
///
/// 영수증 이미지는 저장하지 않는다(OCR 입력으로만 쓰고 버린다). 추출 0건·실패는 빈 staging +
/// 안내 폴백(크래시·차단 없음). macOS 는 카메라 미노출 — 사진 선택만 제공한다.
struct ReceiptScanSheet: View {
  @Environment(\.dismiss) private var dismiss

  /// 추출한 품목 라인들을 호출부로 넘긴다. 빈 배열이면 호출부는 적재하지 않는다.
  let onExtract: ([String]) -> Void

  #if canImport(Vision)
  @State private var model = ReceiptScanViewModel()
  #endif
  @State private var photoItem: PhotosPickerItem?
  /// 선택 사진 로드 Task. 동시에 둘 이상 두지 않고, 새 로드·시트 닫힘 시 취소한다
  /// (인식 경로 `recognizeTask` 와 같은 취소 모델 — 고아 로드가 나중 선택을 덮어쓰지 않게).
  @State private var loadTask: Task<Void, Never>?
  #if os(iOS)
  @State private var showingCamera = false
  #endif

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          intro
          sourceButtons
          statusContent
        }
        .padding(20)
        .frame(maxWidth: .infinity)
      }
      .background(AppColor.screenBackground)
      .navigationTitle("Scan Receipt")
      .compactNavTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
      }
      .onChange(of: photoItem) { _, newItem in
        if let newItem { loadPhoto(newItem) }
      }
      .onDisappear {
        loadTask?.cancel()
        loadTask = nil
        #if canImport(Vision)
        model.cancel()
        #endif
      }
      #if os(iOS)
      .fullScreenCover(isPresented: $showingCamera) {
        CameraImagePicker { image in
          showingCamera = false
          if let image { recognizeUIImage(image) }
        }
        .ignoresSafeArea()
      }
      #endif
    }
  }

  private var intro: some View {
    VStack(spacing: 6) {
      Image(systemName: "doc.text.viewfinder")
        .font(.system(size: 40, weight: .regular))
        .foregroundStyle(AppColor.accent)
      Text("Scan a receipt to add items")
        .font(.appItemBody).foregroundStyle(AppColor.textPrimary)
      Text("We read item names only. The receipt image is not saved.")
        .font(.appCaption).foregroundStyle(AppColor.textMuted)
        .multilineTextAlignment(.center)
    }
    .padding(.top, 8)
  }

  @ViewBuilder
  private var sourceButtons: some View {
    VStack(spacing: 10) {
      #if os(iOS)
      if UIImagePickerController.cameraAvailable {
        AppFullWidthPrimaryButton(title: "Take a photo") { showingCamera = true }
      }
      #endif
      PhotosPicker(selection: $photoItem, matching: .images) {
        HStack(spacing: 8) {
          Image(systemName: "photo.on.rectangle")
          Text("Choose from photos")
        }
        .font(.appValueStrong).foregroundStyle(AppColor.accent)
        .frame(maxWidth: .infinity).frame(height: 52)
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
    }
  }

  @ViewBuilder
  private var statusContent: some View {
    #if canImport(Vision)
    switch model.state {
    case .idle:
      EmptyView()
    case .recognizing:
      HStack(spacing: 10) {
        ProgressView()
        Text("Reading the receipt…").font(.appFootnote).foregroundStyle(AppColor.textMuted)
      }
      .padding(.top, 8)
    case let .recognized(lines):
      recognizedSummary(count: lines.count)
    case .empty:
      noticeText("No items found. Add them manually instead.")
    case .failed:
      noticeText("Couldn't read the receipt. Try another photo or add manually.")
    }
    #else
    noticeText("Receipt scanning isn't available on this device.")
    #endif
  }

  #if canImport(Vision)
  /// 추출 성공 안내 + "칩으로 추가" 합류 버튼. 누르면 라인을 넘기고 시트를 닫는다.
  private func recognizedSummary(count: Int) -> some View {
    VStack(spacing: 10) {
      Text("receipt.found.\(count)")
        .font(.appItemBody).foregroundStyle(AppColor.textPrimary)
      AppFullWidthPrimaryButton(title: "Add to list") {
        if case let .recognized(lines) = model.state {
          onExtract(lines)
        }
        dismiss()
      }
    }
    .padding(.top, 8)
  }
  #endif

  private func noticeText(_ text: LocalizedStringKey) -> some View {
    VStack(spacing: 10) {
      Text(text)
        .font(.appFootnote).foregroundStyle(AppColor.textMuted)
        .multilineTextAlignment(.center)
      Button("Done") {
        onExtract([])
        dismiss()
      }
      .font(.appValueStrong).foregroundStyle(AppColor.accent)
    }
    .padding(.top, 8)
  }

  // MARK: - 이미지 → OCR

  /// 선택한 사진을 데이터로 읽어 CGImage 로 변환 후 인식한다.
  /// 로드는 단일 `loadTask` 로 소유해 새 로드/시트 닫힘 시 이전 로드를 취소한다(순서 비결정성 차단).
  /// 동일 사진 재선택이 다시 onChange 를 발화하도록 소비 직후 `photoItem` 을 nil 로 리셋한다.
  private func loadPhoto(_ item: PhotosPickerItem) {
    loadTask?.cancel()
    photoItem = nil
    loadTask = Task {
      guard let data = try? await item.loadTransferable(type: Data.self) else {
        if !Task.isCancelled { markFailed() }
        return
      }
      guard !Task.isCancelled else { return }
      guard let cgImage = Self.cgImage(from: data) else {
        markFailed()
        return
      }
      recognize(cgImage)
    }
  }

  #if os(iOS)
  /// 카메라로 찍은 UIImage 를 인식한다.
  private func recognizeUIImage(_ image: UIImage) {
    guard let cgImage = image.cgImage else {
      markFailed()
      return
    }
    recognize(cgImage)
  }
  #endif

  #if canImport(Vision)
  private func recognize(_ cgImage: CGImage) {
    model.recognize(cgImage)
  }

  private func markFailed() {
    model.markFailed()
  }
  #else
  private func recognize(_ cgImage: CGImage) {}
  private func markFailed() {}
  #endif

  /// 이미지 데이터 → CGImage. 플랫폼 이미지 타입을 거쳐 변환한다.
  private static func cgImage(from data: Data) -> CGImage? {
    #if os(iOS)
    return UIImage(data: data)?.cgImage
    #elseif os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }
    var rect = CGRect(origin: .zero, size: nsImage.size)
    return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    #else
    return nil
    #endif
  }
}
