# «Eco health» ilovasi maxfiylik siyosati

**Kuchga kirish sanasi:** 2026-yil 6-iyul
**Oxirgi yangilanish:** 2026-yil 6-iyul

> ⚠️ Hujjatni doimiy ochiq URL manzilga joylashtiring va bu URL’ni Google Play Console hamda
> App Store Connect’da koʻrsating.

Ushbu Maxfiylik siyosati **«Eco health»** mobil ilovasi (bundan buyon — «Ilova») qanday
maʼlumotlarni, qaysi maqsadda va qanday asosda qayta ishlashini, shuningdek foydalanuvchining
huquqlarini tushuntiradi.

Ilova operatori (huquq egasi): **Ekologiya va iqlim oʻzgarishi milliy qoʻmitasi**. Ishlab
chiquvchi: **AI laboratoriya** (bundan buyon — «biz»).

Ilovadan foydalanish orqali siz ushbu Siyosat shartlariga rozilik bildirasiz. Agar rozi
boʻlmasangiz, iltimos, Ilovadan foydalanmang.

---

## 1. Qisqacha

- Ilova ovqatlanish, suv, qadamlar va tana koʻrsatkichlari kundaligini yuritishga hamda
  sunʼiy intellekt (AI) yordamida ovqatlanish boʻyicha maʼlumot xarakteridagi tavsiyalar
  olishga yordam beradi.
- **Hisob (account) talab qilinmaydi.** Biz login, parol, telefon raqami yoki e-mail
  soʻramaymiz.
- **Maʼlumotlarning asosiy qismi qurilmangizda mahalliy saqlanadi** va uni tark etmaydi.
- Maʼlumotlar tashqi xizmatlarga **faqat siz AI tavsiyasini soʻraganingizda** yuboriladi.
- Biz **reklama koʻrsatmaymiz** va maʼlumotlaringizni **sotmaymiz**.

---

## 2. Qayta ishlanadigan maʼlumotlar

### 2.1. Siz kiritadigan maʼlumotlar
- Profil: ism (ixtiyoriy), jins, tugʻilgan sana (yosh), boʻy, vazn, faollik darajasi,
  maqsad (vazn kamaytirish / saqlash / oshirish), profil rasmi (ixtiyoriy).
- Kundalik: yeyilgan mahsulot va taomlar, suv miqdori, tana koʻrsatkichlari (yogʻ, mushak
  va boshqalar).

### 2.2. Ilova shakllantiradigan maʼlumotlar
- Qadamlar soni va sarflangan kaloriya bahosi (qurilma qadam sensoridan).
- Hisoblangan koʻrsatkichlar (kaloriya meʼyori, BJU, mikronutriyentlar, vazn tarixi).
- Texnik sozlamalar (til, mavzu, bildirishnoma sozlamalari).

### 2.3. Biz YIGʻMAYDIGAN maʼlumotlar
- Aniq joylashuv, kontaktlar roʻyxati, qoʻngʻiroq/SMS tarixini yigʻmaymiz.
- Reklama identifikatorlari va uchinchi tomon trekerlari/analitikasidan foydalanmaymiz.

---

## 3. Maʼlumotlar qayerda saqlanadi

Yuqorida sanab oʻtilgan barcha maʼlumotlar foydalanuvchi **qurilmasida mahalliy saqlanadi**
(ilovaning ichki xotirasida). Biz serverdagi foydalanuvchi hisobini yuritmaymiz va
kundaligingiz nusxasini oʻz serverlarimizda saqlamaymiz.

---

## 4. AI ovqatlanish tavsiyalari (uchinchi tomonlarga uzatish)

Siz AI tavsiyasini olish tugmasini bosganingizda, Ilova ovqatlanish va profil boʻyicha
**shaxssizlantirilgan maʼlumotlar toʻplamini** shakllantiradi va uni himoyalangan (HTTPS)
ulanish orqali qayta ishlashga yuboradi. Bu — maʼlumotlar qurilmani tark etadigan yagona holat.

**Nima yuboriladi:** yosh, jins, boʻy, vazn, faollik darajasi, maqsad, kunlik meʼyorlar,
kaloriya, BJU va mikronutriyentlar boʻyicha jamlangan va oʻrtacha koʻrsatkichlar, hamda
tanlangan davrda yozilgan mahsulot/taom nomlari.

**Nima yuborilmaydi:** ismingiz, rasmingiz, aloqa maʼlumotlaringiz va aniq joylashuvingiz.

**Kimga va nima uchun:**
1. **Google Firebase (Cloud Functions, App Check)** — soʻrov oʻtadigan Google LLC bulut
   platformasi. Firebase App Check server funksiyasini ruxsatsiz murojaatlardan himoya qiladi.
2. **DeepSeek AI xizmati** — yuborilgan maʼlumotlar toʻplamini qayta ishlab, tavsiya matnini
   qaytaruvchi uchinchi tomon katta til modeli provayderi.

Maʼlumotlar **faqat soʻrovingizga javoban tavsiya shakllantirish uchun** ishlatiladi va biz
tomonimizdan reklama yoki profillash uchun qoʻllanilmaydi. Ushbu provayderlar tomonidan qayta
ishlash ularning oʻz shartlari va maxfiylik siyosatlariga boʻysunadi.

AI funksiyalari internetga ulanishni talab qiladi.

---

## 5. Qurilma ruxsatlari

Ilova quyidagi ruxsatlarni soʻrashi mumkin. Ularning barchasi **majburiy emas** — asosiy
funksiyalar ularsiz ham ishlaydi, ularni qurilma sozlamalarida istalgan vaqtda bekor qilish
mumkin.

| Ruxsat | Nima uchun kerak |
|---|---|
| Bildirishnomalar (`POST_NOTIFICATIONS`) | Ovqat, suv, kun yakuni va tortilish boʻyicha mahalliy eslatmalar. Qurilmada hisoblanadi. |
| Jismoniy faollikni aniqlash (`ACTIVITY_RECOGNITION`) | Qurilma sensori orqali qadam va sarflangan kaloriyani hisoblash. |
| Aniq signal-soatlar (`SCHEDULE_EXACT_ALARM`) | Eslatmalarni oʻz vaqtida yetkazish (berilmasa, aniq boʻlmagan eslatmalar ishlatiladi). |
| Qayta yoqilgandan soʻng ishga tushish (`RECEIVE_BOOT_COMPLETED`) | Qayta yuklashdan soʻng qadam hisoblagichi va eslatmalar jadvalini tiklash. |
| Internet (`INTERNET`) | Faqat AI tavsiyalarini soʻrash uchun. |

Qadam va bildirishnoma maʼlumotlari **qurilmani tark etmaydi**.

---

## 6. Qayta ishlashning huquqiy asoslari

- **Rozilik** — birinchi ishga tushirishda rozilik ekranida (profil maʼlumotlari
  kiritilgandan soʻng) va AI tavsiyasini soʻraganda beriladi.
- **Siz soʻragan funksiyalarni bajarish** — kundalik yuritish va hisob-kitoblar.

Roziligingizni qurilma sozlamalarida tegishli ruxsatlarni oʻchirib va/yoki Ilovadagi
maʼlumotlarni oʻchirib bekor qilishingiz mumkin (7-boʻlimga qarang).

---

## 7. Saqlash, oʻchirish va foydalanuvchi huquqlari

- Maʼlumotlar siz oʻchirmaguningizcha qurilmada saqlanadi.
- Hammasini oʻchirish: **«Profil» → «Maʼlumotlarni tozalash»**.
- Ilovani oʻchirib tashlash ham barcha mahalliy maʼlumotlarni oʻchiradi.
- Biz maʼlumotlaringizni oʻz serverlarimizda saqlamaganimiz uchun, ularga kirish/tuzatish/
  oʻchirish bevosita qurilmadagi Ilova orqali amalga oshiriladi.

---

## 8. Bolalar

Ilova ota-ona yoki qonuniy vakilning roziligisiz, maʼlumotlarni qayta ishlashga mustaqil
rozilik berish uchun mamlakatingiz qonunchiligida belgilangan yoshdan kichik bolalar uchun
moʻljallanmagan. Biz bunday bolalarning maʼlumotlarini ataylab yigʻmaymiz.

---

## 9. Xavfsizlik

AI tavsiyalari uchun maʼlumotlar himoyalangan (HTTPS) ulanish orqali uzatiladi. Server
funksiyasiga murojaatlar Firebase App Check bilan himoyalangan. Shunga qaramay, uzatish yoki
saqlashning hech bir usuli toʻliq xavfsiz emas.

---

## 10. Tibbiy eslatma

Ilova faqat **maʼlumot va maʼlumotnoma xarakteriga** ega boʻlib, **tibbiy vosita emas**. AI
tavsiyalari, meʼyorlar va hisob-kitoblar malakali mutaxassis maslahatini almashtirmaydi hamda
kasallikni tashxislash yoki davolash uchun moʻljallanmagan.

---

## 11. Siyosatdagi oʻzgarishlar

Biz ushbu Siyosatni yangilashimiz mumkin. Muhim oʻzgarishlar yangi yangilanish sanasida aks
ettiriladi va zarur boʻlganda Ilovada qaytadan rozilik soʻrash orqali bildiriladi.

---

## 12. Aloqa

Maʼlumotlarni qayta ishlash boʻyicha savollar uchun: **cproarxangel@gmail.com**.

Operator: **Ekologiya va iqlim oʻzgarishi milliy qoʻmitasi**.
Ishlab chiquvchi: **AI laboratoriya**.
