import Foundation

// 시드 텍스트 en/ko 세트. 그래프 구조는 동일하고 사람이 읽는 이름·문장만 분기한다.

extension SeedText {
  static let korean = SeedText(
    space: "우리집",
    categoryFood: "식품",
    categoryLiving: "생활용품",
    categoryDocs: "서류",
    tagDaily: "자주쓰는",
    tagEmergency: "비상",
    areaKitchen: "주방",
    areaFridge: "냉장고",
    areaLiving: "거실",
    areaBedroom: "안방",
    areaDressRoom: "드레스룸",
    areaBathroom: "욕실",
    areaEntrance: "현관",
    areaStorage: "창고",
    spotFreezer: "냉동실",
    spotFresh: "신선칸",
    spotDoorSide: "문쪽",
    spotUpperCabinet: "상부장",
    spotDrawer1: "서랍 1번째",
    spotNightstand: "협탁",
    itemMilk: "우유",
    itemTofu: "두부",
    itemEgg: "계란",
    itemSoySauce: "간장",
    itemButter: "버터",
    itemKimchi: "김치",
    itemJam: "잼",
    itemSugar: "설탕",
    itemBread: "식빵",
    itemSesameOil: "참기름",
    itemSalt: "소금",
    itemGreenOnion: "대파",
    itemGarlic: "마늘",
    itemOliveOil: "올리브유",
    itemContainer: "밀폐용기",
    itemPowerStrip: "멀티탭",
    itemRemote: "리모컨",
    itemCharger: "충전기",
    itemPassport: "여권",
    itemBankbook: "통장",
    itemEmergencyCash: "비상금",
    itemGlasses: "안경",
    itemWinterCoat: "겨울코트",
    ingRedPepperPowder: "고춧가루",
    ingCookingOil: "식용유",
    ingSoybeanPaste: "된장",
    ingZucchini: "애호박",
    ingChicken: "닭고기",
    ingOnion: "양파",
    ingPorkMince: "다진 돼지고기",
    ingDoubanjiang: "두반장",
    ingSpaghetti: "스파게티면",
    ingTomatoSauce: "토마토소스",
    ingRiceCake: "떡",
    ingGochujang: "고추장",
    ingFishCake: "어묵",
    recipeBraisedTofu: SeedRecipeText(
      title: "두부조림",
      summary: "간장 양념에 졸인 든든한 밑반찬.",
      steps: [
        "두부를 1cm 두께로 썰어 키친타월로 물기를 뺀다.",
        "팬에 기름을 두르고 두부를 노릇하게 부친다.",
        "간장·설탕·다진 마늘·물을 섞어 양념장을 만든다.",
        "두부에 양념장을 붓고 대파를 올려 졸인다.",
      ]
    ),
    recipeSteamedEgg: SeedRecipeText(
      title: "계란찜",
      summary: "뚝배기에 보들보들하게 쪄낸 계란.",
      steps: [
        "계란을 풀고 물·소금을 넣어 잘 섞는다.",
        "뚝배기에 부어 약불로 저으며 익힌다.",
        "대파와 참기름을 올려 마무리한다.",
      ]
    ),
    recipeFrenchToast: SeedRecipeText(
      title: "프렌치토스트",
      summary: "우유와 계란물에 적셔 구운 달콤한 아침 식사.",
      steps: [
        "우유·계란·설탕을 섞어 계란물을 만든다.",
        "식빵을 계란물에 충분히 적신다.",
        "버터를 두른 팬에 양면을 노릇하게 굽는다.",
      ]
    ),
    recipeKimchiFriedRice: SeedRecipeText(
      title: "김치볶음밥",
      summary: "잘 익은 김치로 볶아낸 한 그릇 식사.",
      steps: [
        "김치를 잘게 썰어 기름에 볶는다.",
        "밥을 넣고 함께 볶아 간을 맞춘다.",
        "대파를 넣고 계란프라이를 올린다.",
      ]
    ),
    recipeDoenjangStew: SeedRecipeText(
      title: "된장찌개",
      summary: "구수한 된장으로 끓인 기본 찌개.",
      steps: [
        "냄비에 물을 붓고 된장을 풀어 끓인다.",
        "애호박과 두부를 먹기 좋게 썰어 넣는다.",
        "다진 마늘을 넣고 중불에서 끓인다.",
        "대파를 넣고 한소끔 더 끓여 마무리한다.",
      ]
    ),
    recipeButterSoyEggRice: SeedRecipeText(
      title: "버터간장계란밥",
      summary: "재료만 있으면 5분이면 완성되는 든든한 한 끼.",
      steps: [
        "팬에 버터를 녹이고 계란프라이를 만든다.",
        "따뜻한 밥에 버터·간장·참기름을 넣고 비빈다.",
        "계란프라이를 올려 함께 비벼 먹는다.",
      ]
    ),
    recipeOyakodon: SeedRecipeText(
      title: "오야코동",
      summary: "닭고기와 계란을 간장 국물에 졸여 올린 일본식 덮밥.",
      steps: [
        "간장·설탕·물을 섞어 양념 국물을 만든다.",
        "양파와 닭고기를 넣고 국물에 졸인다.",
        "풀어둔 계란을 둘러 부어 반숙으로 익힌다.",
        "밥 위에 올리고 대파를 뿌린다.",
      ]
    ),
    recipeMapoTofu: SeedRecipeText(
      title: "마파두부",
      summary: "두반장으로 매콤하게 볶아낸 사천식 두부 요리.",
      steps: [
        "두부를 깍둑썰기 하고 다진 마늘을 준비한다.",
        "팬에 다진 돼지고기를 볶다가 두반장을 넣는다.",
        "간장·물을 넣고 두부를 넣어 졸인다.",
        "대파를 넣고 전분물로 농도를 맞춘다.",
      ]
    ),
    recipeTomatoPasta: SeedRecipeText(
      title: "토마토파스타",
      summary: "토마토소스에 버무린 기본 스파게티.",
      steps: [
        "끓는 소금물에 스파게티면을 삶는다.",
        "올리브유에 다진 마늘을 볶아 향을 낸다.",
        "토마토소스를 넣고 끓인다.",
        "삶은 면을 넣고 버무려 소금으로 간한다.",
      ]
    ),
    recipeTteokbokki: SeedRecipeText(
      title: "떡볶이",
      summary: "고추장 양념에 떡과 어묵을 졸인 매콤한 분식.",
      steps: [
        "물에 고추장·설탕·간장을 풀어 양념을 만든다.",
        "떡과 어묵을 넣고 끓인다.",
        "대파를 넣고 양념이 졸아들 때까지 끓인다.",
      ]
    )
  )

  static let english = SeedText(
    space: "My Home",
    categoryFood: "Food",
    categoryLiving: "Household",
    categoryDocs: "Documents",
    tagDaily: "Frequently used",
    tagEmergency: "Emergency",
    areaKitchen: "Kitchen",
    areaFridge: "Fridge",
    areaLiving: "Living Room",
    areaBedroom: "Bedroom",
    areaDressRoom: "Dressing Room",
    areaBathroom: "Bathroom",
    areaEntrance: "Entrance",
    areaStorage: "Storage",
    spotFreezer: "Freezer",
    spotFresh: "Fresh compartment",
    spotDoorSide: "Door shelf",
    spotUpperCabinet: "Upper cabinet",
    spotDrawer1: "First drawer",
    spotNightstand: "Nightstand",
    itemMilk: "Milk",
    itemTofu: "Tofu",
    itemEgg: "Eggs",
    itemSoySauce: "Soy sauce",
    itemButter: "Butter",
    itemKimchi: "Kimchi",
    itemJam: "Jam",
    itemSugar: "Sugar",
    itemBread: "Bread",
    itemSesameOil: "Sesame oil",
    itemSalt: "Salt",
    itemGreenOnion: "Green onion",
    itemGarlic: "Garlic",
    itemOliveOil: "Olive oil",
    itemContainer: "Food container",
    itemPowerStrip: "Power strip",
    itemRemote: "Remote",
    itemCharger: "Charger",
    itemPassport: "Passport",
    itemBankbook: "Bankbook",
    itemEmergencyCash: "Emergency cash",
    itemGlasses: "Glasses",
    itemWinterCoat: "Winter coat",
    ingRedPepperPowder: "Red pepper powder",
    ingCookingOil: "Cooking oil",
    ingSoybeanPaste: "Soybean paste",
    ingZucchini: "Zucchini",
    ingChicken: "Chicken",
    ingOnion: "Onion",
    ingPorkMince: "Ground pork",
    ingDoubanjiang: "Doubanjiang",
    ingSpaghetti: "Spaghetti",
    ingTomatoSauce: "Tomato sauce",
    ingRiceCake: "Rice cakes",
    ingGochujang: "Gochujang",
    ingFishCake: "Fish cake",
    recipeBraisedTofu: SeedRecipeText(
      title: "Braised Tofu",
      summary: "A hearty side dish simmered in soy sauce seasoning.",
      steps: [
        "Cut the tofu into 1cm slices and pat dry with paper towels.",
        "Heat oil in a pan and fry the tofu until golden.",
        "Mix soy sauce, sugar, minced garlic, and water for the sauce.",
        "Pour the sauce over the tofu, top with green onion, and simmer.",
      ]
    ),
    recipeSteamedEgg: SeedRecipeText(
      title: "Steamed Egg",
      summary: "Soft, fluffy eggs steamed in an earthenware pot.",
      steps: [
        "Beat the eggs and mix well with water and salt.",
        "Pour into an earthenware pot and cook over low heat, stirring.",
        "Top with green onion and sesame oil to finish.",
      ]
    ),
    recipeFrenchToast: SeedRecipeText(
      title: "French Toast",
      summary: "A sweet breakfast of bread soaked in milk and egg.",
      steps: [
        "Mix milk, eggs, and sugar to make the egg batter.",
        "Soak the bread thoroughly in the batter.",
        "Fry both sides golden in a buttered pan.",
      ]
    ),
    recipeKimchiFriedRice: SeedRecipeText(
      title: "Kimchi Fried Rice",
      summary: "A one-bowl meal stir-fried with ripe kimchi.",
      steps: [
        "Chop the kimchi finely and stir-fry in oil.",
        "Add rice and stir-fry together, adjusting the seasoning.",
        "Add green onion and top with a fried egg.",
      ]
    ),
    recipeDoenjangStew: SeedRecipeText(
      title: "Soybean Paste Stew",
      summary: "A basic stew simmered with savory soybean paste.",
      steps: [
        "Pour water into a pot, dissolve soybean paste, and bring to a boil.",
        "Cut zucchini and tofu into bite-size pieces and add.",
        "Add minced garlic and simmer over medium heat.",
        "Add green onion and boil once more to finish.",
      ]
    ),
    recipeButterSoyEggRice: SeedRecipeText(
      title: "Butter Soy Egg Rice",
      summary: "A filling meal ready in 5 minutes if you have the ingredients.",
      steps: [
        "Melt butter in a pan and fry an egg.",
        "Add butter, soy sauce, and sesame oil to warm rice and mix.",
        "Top with the fried egg and mix together as you eat.",
      ]
    ),
    recipeOyakodon: SeedRecipeText(
      title: "Oyakodon",
      summary: "A Japanese rice bowl topped with chicken and egg simmered in soy broth.",
      steps: [
        "Mix soy sauce, sugar, and water for the broth.",
        "Add onion and chicken and simmer in the broth.",
        "Pour in beaten egg and cook until softly set.",
        "Place over rice and sprinkle with green onion.",
      ]
    ),
    recipeMapoTofu: SeedRecipeText(
      title: "Mapo Tofu",
      summary: "A Sichuan tofu dish stir-fried spicy with doubanjiang.",
      steps: [
        "Cube the tofu and prepare minced garlic.",
        "Stir-fry ground pork in a pan, then add doubanjiang.",
        "Add soy sauce and water, then add the tofu and simmer.",
        "Add green onion and thicken with a starch slurry.",
      ]
    ),
    recipeTomatoPasta: SeedRecipeText(
      title: "Tomato Pasta",
      summary: "Basic spaghetti tossed in tomato sauce.",
      steps: [
        "Boil the spaghetti in salted boiling water.",
        "Stir-fry minced garlic in olive oil to release the aroma.",
        "Add tomato sauce and bring to a boil.",
        "Add the boiled pasta, toss, and season with salt.",
      ]
    ),
    recipeTteokbokki: SeedRecipeText(
      title: "Tteokbokki",
      summary: "A spicy street snack of rice cakes and fish cake in gochujang sauce.",
      steps: [
        "Dissolve gochujang, sugar, and soy sauce in water for the sauce.",
        "Add rice cakes and fish cake and bring to a boil.",
        "Add green onion and boil until the sauce thickens.",
      ]
    )
  )
}
