/// Product catalogue — from the Eco design store (store.jsx::PRODUCTS).
/// Local and offline-first; Supabase search joins in the sync phase.
class Product {
  final String name;
  final String desc;
  final int kcal; // per 100 г
  final bool fav;

  const Product({required this.name, required this.desc, required this.kcal, this.fav = false});
}

const kProducts = [
  Product(name: 'Салат «Цезарь»', desc: 'Курица, пармезан, соус', kcal: 165, fav: true),
  Product(name: 'Куриная грудка', desc: 'Запечённая, без кожи', kcal: 113, fav: true),
  Product(name: 'Гречка отварная', desc: 'На воде, без соли', kcal: 92),
  Product(name: 'Творог 5%', desc: 'Зернёный', kcal: 121, fav: true),
  Product(name: 'Банан', desc: 'Свежий', kcal: 89),
  Product(name: 'Овсянка на молоке', desc: 'С ягодами', kcal: 134),
  Product(name: 'Лосось', desc: 'Слабосолёный', kcal: 208),
  Product(name: 'Авокадо', desc: 'Половина плода', kcal: 160, fav: true),
];
