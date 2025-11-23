import 'recipe.dart';

const List<Recipe> kMockRecipes = [
  Recipe(
    id: 'masala-dosa-blr',
    name: 'Bangalore Masala Dosa',
    imageUrl: 'assets/images/banglore_masala_dosa.jpg.png',
    durationMinutes: 35,
    kcal: 410,
    category: 'Breakfast',
    ingredients: [
      'Dosa batter',
      '3 medium potatoes, boiled and mashed',
      '1 onion, finely chopped',
      '2 green chilies, chopped',
      '1/2 tsp mustard seeds',
      'Curry leaves',
      'Turmeric powder',
      'Salt to taste',
      '1/2 teaspoon of Urad dal (optional)',
      'Coconut chutney for serving',
      'Oil or ghee for cooking'
    ],
    instructions: [
      'Heat oil in a pan, add mustard seeds and let them splutter',
      'Add Urad dal and curry leaves, sauté for a minute',
      'Add onions and green chilies, sauté until golden',
      'Add turmeric powder, salt mashed potatoes and spices, cook for 5 minutes',
      'Heat dosa tawa and spread batter in circular motion',
      'Add oil around edges and cook until crispy',
      'Place potato filling and fold dosa',
      'Serve hot with coconut chutney'
    ],
  ),
  Recipe(
    id: 'chicken-curry',
    name: 'Chicken Curry',
    imageUrl: 'assets/images/chicken_curry.jpg.png',
    durationMinutes: 50,
    kcal: 520,
    category: 'Dinner',
    ingredients: [
      '500g chicken pieces',
      '2 onions, finely chopped',
      '3 tomatoes, pureed',
      '2 tbsp ginger-garlic paste',
      'Garam masala',
      'Turmeric powder',
      'Red chili powder',
      'Fresh coriander for garnish'
    ],
    instructions: [
      'Marinate chicken with spices for 30 minutes',
      'In a pan, heat oil and add whole spices',
      'Sauté onions until golden brown',
      'Add ginger-garlic paste and cook',
      'Add tomato puree and spices',
      'Add chicken and cook until tender for about 5-7 minutes',
      'Simmer until gravy thickens',
      'Garnish with fresh coriander'
    ],
  ),
  Recipe(
    id: 'hyderabadi-biryani',
    name: 'Hyderabadi Biryani',
    imageUrl: 'assets/images/hyderbadi_biriyani.jpg.png',
    durationMinutes: 65,
    kcal: 680,
    category: 'Lunch',
    ingredients: [
      '2 cups Basmati rice',
      '500g chicken/mutton',
      'Saffron strands',
      'Mint and coriander leaves',
      'Fried onions',
      'Yogurt for marination',
      'Whole spices (cardamom, cinnamon)',
      'Ghee for cooking'
    ],
    instructions: [
      'Marinate meat with yogurt and spices for about 4 hours',
      'Wash and soak rice for 30 minutes',
      'Cook rice with whole spices until 70% done',
      'Layer marinated meat and partially cooked rice',
      'Add saffron milk and fried onions',
      'Seal pot with dough and slow cook',
      'Let it rest for 10 minutes',
      'Serve hot with raita'
    ],
  ),
  Recipe(
    id: 'mutton-rogan-josh',
    name: 'Mutton Rogan Josh',
    imageUrl: 'assets/images/mutton_rogan_josh.jpg.png',
    durationMinutes: 60,
    kcal: 540,
    category: 'Dinner',
    ingredients: [
      '500g mutton pieces',
      'Kashmiri red chilies',
      'Yogurt',
      'Fennel seeds',
      'Ginger-garlic paste',
      'Whole spices (bay leaves, cardamom)',
      'Onions and tomatoes',
      'Fresh cream'
    ],
    instructions: [
      'Heat oil and add whole spices',
      'Add onions and cook until brown',
      'Add ginger-garlic paste',
      'Add mutton and brown it well',
      'Add spices and yogurt, cook',
      'Simmer until meat is tender',
      'Finish with cream and serve'
    ],
  ),
  Recipe(
    id: 'kerala-style-avial',
    name: 'Kerala Style Avial',
    imageUrl: 'assets/images/kerala_style_avial.jpg.png',
    durationMinutes: 25,
    kcal: 320,
    category: 'Breakfast',
    ingredients: [
      'Mixed vegetables (carrots, beans, drumsticks)',
      'Grated coconut',
      'Curry leaves',
      'Green chilies',
      'Turmeric powder',
      'Curd/yogurt',
      'Coconut oil',
      'Salt to taste'
    ],
    instructions: [
      'Cut vegetables into uniform size',
      'Cook vegetables until half done for about 10 minutes with turmeric and salt',
      'Grind coconut with green chilies',
      'Add ground paste to cooked vegetables',
      'Mix in beaten curd',
      'Season with curry leaves',
      'Drizzle coconut oil and serve'
    ],
  ),
  Recipe(
    id: 'filter-coffee',
    name: 'South Indian Filter Coffee',
    imageUrl:
        'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=1200',
    durationMinutes: 15,
    kcal: 95,
    category: 'Beverages',
    ingredients: [
      'Fresh coffee powder (80% coffee, 20% chicory)',
      'Whole milk',
      'Sugar to taste',
      'Water for brewing',
    ],
    instructions: [
      'Add coffee powder to filter',
      'Add hot water and let it drip',
      'Heat milk until almost boiling',
      'Mix decoction with hot milk',
      'Add sugar to taste',
      'Pour between containers to create foam',
      'Serve hot in traditional davara-tumbler'
    ],
  ),
];
