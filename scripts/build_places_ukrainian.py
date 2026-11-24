"""Builds places_ukrainian_{ch,de,at}.json: hand-checked places that matter to Ukrainians in
Switzerland, Germany and Austria.

Every entry carries the page its address was confirmed on (`source`). Coordinates come from the
OpenStreetMap Nominatim geocoder. Re-run after editing ENTRIES; do not hand-edit the JSON:

    python3 -I scripts/build_places_ukrainian.py sweezy/sweezy/Resources/AppContent/seeds
"""
import json, re, sys, time, uuid, urllib.parse, urllib.request

NS = uuid.UUID("6f1c2b1e-9a57-4d3e-8c11-5a0a7a3c2e01")
UA = "SweezyPlacesImport/1.0 (+https://sweezy-api.onrender.com)"

def hours(days, open_, close):
    oh, om = map(int, open_.split(":")); ch, cm = map(int, close.split(":"))
    return [{"weekday": d, "openTime": {"hour": oh, "minute": om}, "closeTime": {"hour": ch, "minute": cm}, "isClosed": False} for d in days]

SUN, MON, TUE, WED, THU, FRI, SAT = 1, 2, 3, 4, 5, 6, 7

ENTRIES = [
    dict(key="embassy-bern", id="5d36f391-e2f8-5109-893b-0abb5481c473",
         name="Посольство України у Швейцарії", type="government", category="embassy",
         street="Feldeggweg", number="5", zip="3005", city="Bern", canton="BE",
         query="Feldeggweg 5, 3005 Bern",
         uk="Консульські послуги для громадян України: паспорти, довідки, нотаріальні дії. Прийом за попереднім записом.",
         en="Consular services for Ukrainian citizens: passports, certificates, notarial acts. By appointment.",
         de="Konsularische Dienste für ukrainische Staatsangehörige: Pässe, Bescheinigungen, Beglaubigungen. Nach Terminvereinbarung.",
         phone="+41 31 352 23 16", email="emb_ch@mfa.gov.ua", website="https://switzerland.mfa.gov.ua",
         languages=["uk", "en", "de"], services=["Паспорти", "Консульські довідки", "Нотаріальні дії"],
         source="https://www.eda.admin.ch/countries/ukraine/fr/home/vivre-a/representations-en-ch.html"),
    dict(key="sem-status-s", name="Реєстрація статусу S (MZH Sand-Schönbühl)", type="government", category="migration_office",
         street="Moosstrasse", number="28", zip="3322", city="Urtenen-Schönbühl", canton="BE",
         query="Moosstrasse 28, 3322 Urtenen-Schönbühl",
         uk="Єдине місце особистої реєстрації для статусу захисту S. Якщо є житло і документи — спершу запишіться онлайн у RegisterMe.",
         en="The only in-person registration point for protection status S. With housing and ID, book a slot in RegisterMe first.",
         de="Einziger Ort für die persönliche Registrierung zum Schutzstatus S. Mit Unterkunft und Ausweis zuerst Termin in RegisterMe buchen.",
         website="https://www.sem.admin.ch/sem/de/home/asyl/ukraine.html",
         languages=["de", "fr", "en"], services=["Статус S", "Онлайн-запис RegisterMe"],
         source="https://www.sem.admin.ch/sem/de/home/asyl/ukraine.html"),
    dict(key="ugcc-zurich", name="Українська греко-католицька громада Цюриха", type="community", category="religious_center",
         street="Weinbergstrasse", number="32", zip="8006", city="Zürich", canton="ZH",
         query="Liebfrauenkirche, Weinbergstrasse, Zürich",
         uk="Літургія українською щонеділі о 14:00 у крипті церкви Liebfrauen. Після служби — катехеза для дітей.",
         en="Liturgy in Ukrainian every Sunday at 14:00 in the crypt of Liebfrauen church, followed by children's catechesis.",
         de="Ukrainische Liturgie jeden Sonntag um 14 Uhr in der Krypta der Liebfrauenkirche, danach Kinderkatechese.",
         website="https://www.ugcc.ch", languages=["uk"], services=["Богослужіння українською", "Катехеза для дітей"],
         hours=hours([SUN], "14:00", "16:30"),
         source="https://www.forum-magazin.ch/ukrainische-mission/"),
    dict(key="ugcc-basel", name="Українська греко-католицька громада Базеля", type="community", category="religious_center",
         street="Holbeinstrasse", number="30", zip="4051", city="Basel", canton="BS",
         query="Holbeinstrasse 30, 4051 Basel",
         uk="Літургія українською в церкві St. Marien, зазвичай у 2-гу та 4-ту неділю місяця о 15:00.",
         en="Ukrainian liturgy at St. Marien church, usually on the 2nd and 4th Sunday of the month at 15:00.",
         de="Ukrainische Liturgie in der Kirche St. Marien, meist am 2. und 4. Sonntag im Monat um 15 Uhr.",
         email="basel.ugkk@gmail.com", website="https://www.ugcc.ch", languages=["uk"], services=["Богослужіння українською"],
         source="https://www.inforel.ch/wissen/portraets-der-religionscommunity/ukrainische-seelsorge"),
    dict(key="ugcc-bern", name="Українська греко-католицька громада Берна", type="community", category="religious_center",
         street="Taubenstrasse", number="4", zip="3011", city="Bern", canton="BE",
         query="Dreifaltigkeitskirche, Bern",
         uk="Богослужіння українською в крипті базиліки Dreifaltigkeit, неділя о 12:00, після служби — спільний обід. У цьому ж будинку працює українська школа «Рідне слово».",
         en="Ukrainian services in the crypt of the Dreifaltigkeit basilica, Sundays at 12:00. Check ugcc.ch for the schedule.",
         de="Ukrainische Gottesdienste in der Krypta der Basilika Dreifaltigkeit, sonntags 12 Uhr. Plan auf ugcc.ch prüfen.",
         website="https://www.ugcc.ch", languages=["uk"], services=["Богослужіння українською"],
         hours=hours([SUN], "12:00", "13:30"),
         source="https://www.pfarrblattbern.ch/artikel/wir-brauchen-auch-seelischen-beistand"),
    dict(key="uoc-wallisellen", name="Українська православна парафія св. Андрія Первозванного", type="community", category="religious_center",
         street="Zentralstrasse", number="10", zip="8304", city="Wallisellen", canton="ZH",
         query="Zentralstrasse 10, 8304 Wallisellen",
         uk="Українська православна громада біля Цюриха. Розклад служб — на сайті парафії.",
         en="Ukrainian Orthodox parish near Zurich. Service schedule on the parish website.",
         de="Ukrainisch-orthodoxe Gemeinde bei Zürich. Gottesdienstplan auf der Website der Gemeinde.",
         website="https://www.ukrhram.com/", languages=["uk"], services=["Богослужіння українською"],
         source="https://orthodoxie.ch/de/deutsch/verzeichnis/zuerich-ukrainisch-orthodoxe-kirchengemeinde-des-heiligen-apostels-andreas/"),
    dict(key="hub-ticino", name="Ukraine Hub Ticino", type="community", category="community_center",
         street="Via Vincenzo Vela", number="4", zip="6830", city="Chiasso", canton="TI",
         query="Via Vincenzo Vela 4, 6830 Chiasso",
         uk="Інформаційний і громадський центр для українців у Тічино: інтеграція, волонтерство, події громади.",
         en="Information and community centre for Ukrainians in Ticino: integration, volunteering, community events.",
         de="Informations- und Begegnungszentrum für Ukrainer:innen im Tessin: Integration, Freiwilligenarbeit, Anlässe.",
         languages=["uk", "it"], services=["Інформаційна підтримка", "Події громади"],
         source="https://mezha.net/eng/bukvy/f2e9dd66_ukraine_hub_ticino/"),
    dict(key="ukrainehilfe-zentralschweiz", name="Ukrainehilfe Zentralschweiz", type="community", category="community_center",
         street="St.-Karli-Strasse", number="71a", zip="6004", city="Luzern", canton="LU",
         query="St.-Karli-Strasse 71, 6004 Luzern",
         uk="Волонтерська організація в Люцерні: гуманітарна допомога, освітні й культурні проєкти.",
         en="Volunteer organisation in Lucerne: humanitarian aid, education and culture projects.",
         de="Freiwilligenorganisation in Luzern: humanitäre Hilfe, Bildungs- und Kulturprojekte.",
         email="info@ukrainehilfe-zentralschweiz.ch", website="https://ukrainehilfe-zentralschweiz.ch",
         languages=["uk", "de"], services=["Гуманітарна допомога", "Культурні проєкти"],
         source="https://ukrainehilfe-zentralschweiz.ch/unsere-projekte/"),
    dict(key="heilsarmee-zentral", name="Hope for Ukraine · Heilsarmee Zürich-Zentral", type="social", category="food_assistance",
         street="Ankerstrasse", number="31", zip="8004", city="Zürich", canton="ZH",
         query="Ankerstrasse 31, 8004 Zürich",
         uk="Обід за 3 CHF і роздача продуктів (Пн, Ср, Пт 12:00–13:00). У п'ятницю 14:30–16:30 — кава й розмовна німецька.",
         en="Lunch for CHF 3 and food distribution (Mon, Wed, Fri 12:00–13:00). Fridays 14:30–16:30: coffee and German conversation.",
         de="Mittagessen für 3 CHF und Lebensmittelabgabe (Mo, Mi, Fr 12–13 Uhr). Freitags 14.30–16.30: Kaffee & Deutsch-Konversation.",
         phone="+41 44 242 53 89", website="https://hope-for-ukraine.heilsarmee.ch/de/region-zuerich/",
         languages=["de", "en"], services=["Обід за 3 CHF", "Продукти", "Розмовна німецька"],
         hours=hours([MON, WED, FRI], "12:00", "13:00"),
         source="https://hope-for-ukraine.heilsarmee.ch/de/region-zuerich/"),
    dict(key="heilsarmee-nord", name="Hope for Ukraine · Heilsarmee Zürich Nord", type="social", category="food_assistance",
         street="Saatlenstrasse", number="256", zip="8050", city="Zürich", canton="ZH",
         query="Saatlenstrasse 256, 8050 Zürich",
         uk="Обід за 3 CHF (Пн, Вт, Чт, Пт 11:45–13:00). Щосереди 13:30–16:30 — Kids & Fun для дітей до 6 класу.",
         en="Lunch for CHF 3 (Mon, Tue, Thu, Fri 11:45–13:00). Wednesdays 13:30–16:30: Kids & Fun for children up to grade 6.",
         de="Mittagessen für 3 CHF (Mo, Di, Do, Fr 11.45–13 Uhr). Mittwochs 13.30–16.30: Kids & Fun bis 6. Klasse.",
         phone="+41 44 325 10 90", website="https://hope-for-ukraine.heilsarmee.ch/de/region-zuerich/",
         languages=["de", "en"], services=["Обід за 3 CHF", "Дитячий клуб"],
         hours=hours([MON, TUE, THU, FRI], "11:45", "13:00"),
         source="https://hope-for-ukraine.heilsarmee.ch/de/region-zuerich/"),
    dict(key="hope-brocki", name="Hope Brocki · одяг для біженців", type="social", category="secondhand_shop",
         street="Ankerstrasse", number="23", zip="8004", city="Zürich", canton="ZH",
         query="Ankerstrasse 23, 8004 Zürich",
         uk="Одяг для біженців за символічною ціною від Армії Спасіння.",
         en="Clothing for refugees at a symbolic price, run by the Salvation Army.",
         de="Kleider für Geflüchtete zu symbolischen Preisen, betrieben von der Heilsarmee.",
         website="https://hope-for-ukraine.heilsarmee.ch/de/region-zuerich/",
         languages=["de"], services=["Одяг"],
         source="https://hope-for-ukraine.heilsarmee.ch/de/region-zuerich/"),
    # --- Romandie parishes and culture
    dict(key="ugcc-geneve", name="Українська греко-католицька громада Женеви", type="community", category="religious_center",
         street="Avenue de Saint-Paul", number="6", zip="1223", city="Cologny", canton="GE",
         query="Église Saint-Paul, Avenue de Saint-Paul, Cologny",
         uk="Літургія українською щонеділі о 14:30 у церкві Saint-Paul (Колоньї, біля Женеви).",
         en="Ukrainian liturgy every Sunday at 14:30 at Saint-Paul church in Cologny near Geneva.",
         de="Ukrainische Liturgie jeden Sonntag um 14.30 Uhr in der Kirche Saint-Paul in Cologny bei Genf.",
         website="https://ugcc.fr/fr/location/geneve/", languages=["uk", "fr"], services=["Богослужіння українською"],
         hours=hours([SUN], "14:30", "16:00"), source="https://ugcc.fr/fr/location/geneve/"),
    dict(key="ugcc-lausanne", name="Українська греко-католицька громада Лозанни", type="community", category="religious_center",
         street="Chemin de Beau-Rivage", number="3", zip="1006", city="Lausanne", canton="VD",
         query="Église du Sacré-Cœur, Chemin de Beau-Rivage, Lausanne",
         uk="Літургія українською в церкві Sacré-Cœur (Уші), 1-ша та 3-тя неділя місяця о 14:00.",
         en="Ukrainian liturgy at Sacré-Cœur church in Ouchy, 1st and 3rd Sunday of the month at 14:00.",
         de="Ukrainische Liturgie in der Kirche Sacré-Cœur in Ouchy, 1. und 3. Sonntag im Monat um 14 Uhr.",
         website="https://ugcc.fr/fr/location/lausanne/", languages=["uk", "fr"], services=["Богослужіння українською"],
         source="https://ugcc.fr/fr/location/lausanne/"),
    dict(key="svitanok-geneve", name="Ансамбль українського танцю «СвіТанок»", type="community", category="cultural_center",
         street="Rue Saint-Jean", number="60", zip="1203", city="Genève", canton="GE",
         query="Rue Saint-Jean 60, 1203 Genève", zips=["1203", "1211"],  # OSM files the school under 1211
         uk="Заняття українським народним танцем щосуботи 9:00–10:00 для дітей, батьків і вчителів. Організатор — Ukrainian Women in Switzerland, що також веде українську школу в Женеві.",
         en="Ukrainian folk dance classes every Saturday 9:00–10:00 for children, parents and teachers, run by Ukrainian Women in Switzerland, which also runs the Ukrainian school in Geneva.",
         de="Ukrainischer Volkstanz jeden Samstag 9–10 Uhr für Kinder, Eltern und Lehrpersonen, organisiert von Ukrainian Women in Switzerland, die auch die ukrainische Schule in Genf führen.",
         email="dances@femmes-ukrainiennes.ch", website="https://femmes-ukrainiennes.ch/fra/",
         languages=["uk", "fr"], services=["Народний танець", "Українська школа"],
         hours=hours([SAT], "09:00", "10:00"), source="https://femmes-ukrainiennes.ch/fra/"),
    # --- Bern: meeting points and help listed by Ukraine-Hilfe Bern
    dict(key="paulus-ukraine-cafe", name="Ukraine-Café · Kirchgemeinde Paulus", type="community", category="community_cafe",
         street="Freiestrasse", number="20", zip="3012", city="Bern", canton="BE",
         query="Freiestrasse 20, 3012 Bern",
         uk="Щовівторка 14:00–16:00: кава, чай, спілкування українською, російською, англійською та німецькою. У понеділок о 19:30 тут співає українсько-швейцарський хор «Співдружба».",
         en="Every Tuesday 14:00–16:00: coffee, tea and conversation in Ukrainian, Russian, English and German. Mondays at 19:30 the Ukrainian-Swiss choir Spivdruzhba rehearses here.",
         de="Jeden Dienstag 14–16 Uhr: Kaffee, Tee und Austausch auf Ukrainisch, Russisch, Englisch und Deutsch. Montags 19.30 Uhr probt hier der ukrainisch-schweizerische Chor Spivdruzhba.",
         phone="+41 31 309 00 05", website="https://www.paulus.refbern.ch/de/angebote/angebote-fuer-gefluechtete-375.html",
         languages=["uk", "de", "en"], services=["Кава та спілкування", "Хор «Співдружба»", "Розмовна німецька (Пн 16:00)"],
         hours=hours([TUE], "14:00", "16:00"),
         source="https://www.paulus.refbern.ch/de/angebote/angebote-fuer-gefluechtete-375.html"),
    dict(key="ukr-school-bern", name="Українська школа Берн", type="education", category="school",
         street="Marktgasse", number="32", zip="3011", city="Bern", canton="BE",
         query="Marktgasse 32, 3011 Bern",
         uk="Школа й садочок українською, вечірня ігрова кімната, творчі майстерні. Організатор — Verein Ukraine Schweiz Bern.",
         en="Ukrainian-language school and kindergarten, evening playroom and creative workshops, run by Verein Ukraine Schweiz Bern.",
         de="Ukrainische Schule und Kindergarten, Abend-Spielzimmer und Kreativworkshops, getragen vom Verein Ukraine Schweiz Bern.",
         languages=["uk"], services=["Школа", "Садочок", "Творчі майстерні"], source="https://www.ukraine-hilfe-bern.ch/angebote"),
    dict(key="st-michael-psy", name="Психологічна допомога українцям · Pfarrei St. Michael", type="healthcare", category="mental_health",
         street="Gossetstrasse", number="8", zip="3084", city="Wabern", canton="BE",
         query="Gossetstrasse 8, 3084 Wabern",
         uk="Безкоштовні групи та індивідуальні сесії з психологом для українців, щотижня. Запис через форму Ukraine-Hilfe Bern.",
         en="Free weekly group and individual sessions with a psychologist for Ukrainians. Sign up via the Ukraine-Hilfe Bern form.",
         de="Kostenlose wöchentliche Gruppen- und Einzelsitzungen mit Psycholog:innen für Ukrainer:innen. Anmeldung über Ukraine-Hilfe Bern.",
         website="https://www.ukraine-hilfe-bern.ch/angebote", languages=["uk", "de"], services=["Безкоштовна психологічна підтримка"], source="https://www.ukraine-hilfe-bern.ch/angebote"),
    dict(key="vhs-bern-deutsch", name="Безкоштовна німецька для статусу S · VHS Bern", type="education", category="language_school",
         street="Grabenpromenade", number="3", zip="3011", city="Bern", canton="BE",
         query="Grabenpromenade 3, 3011 Bern",
         uk="Безкоштовні курси німецької для українців зі статусом S. Тест на рівень — Пн–Пт 10:00–17:00.",
         en="Free German courses for Ukrainians with S status. Placement test Mon–Fri 10:00–17:00.",
         de="Kostenlose Deutschkurse für Ukrainer:innen mit Status S. Einstufungstest Mo–Fr 10–17 Uhr.",
         languages=["de"], services=["Німецька мова", "Статус S"],
         hours=hours([MON, TUE, WED, THU, FRI], "10:00", "17:00"), source="https://www.ukraine-hilfe-bern.ch/angebote"),
    dict(key="rechtsberatung-bern", name="Berner Rechtsberatungsstelle für Menschen in Not", type="legal", category="legal_aid",
         street="Eigerplatz", number="5", zip="3007", city="Bern", canton="BE",
         query="Eigerplatz 5, 3007 Bern",
         uk="Безкоштовна юридична консультація: статус S, житло, робота, соцдопомога.",
         en="Free legal advice: S status, housing, work, social assistance.",
         de="Kostenlose Rechtsberatung: Status S, Wohnen, Arbeit, Sozialhilfe.",
         languages=["de"], services=["Безкоштовна юридична консультація"], source="https://www.ukraine-hilfe-bern.ch/angebote"),
    dict(key="caritas-markt-bern", name="Caritas-Markt Bern", type="social", category="food_assistance",
         street="Brunnmattstrasse", number="44", zip="3007", city="Bern", canton="BE",
         query="Brunnmattstrasse 44, 3007 Bern",
         uk="Дешеві продукти для людей з низьким доходом (потрібна картка KulturLegi або довідка про соцдопомогу).",
         en="Low-cost groceries for people on low incomes (KulturLegi or proof of social assistance needed).",
         de="Günstige Lebensmittel für Menschen mit wenig Geld (KulturLegi oder Sozialhilfe-Nachweis).",
         languages=["de"], services=["Дешеві продукти"],
         hours=hours([TUE, WED, THU, FRI], "10:00", "18:30") + hours([MON], "14:00", "18:30") + hours([SAT], "10:00", "14:00"),
         source="https://www.ukraine-hilfe-bern.ch/angebote"),
    dict(key="treffpunkt-ostermundigen", name="Treffpunkt Ostermundigen", type="community", category="community_cafe",
         street="Obere Zollgasse", number="31", zip="3072", city="Ostermundigen", canton="BE",
         query="Obere Zollgasse 31, 3072 Ostermundigen",
         uk="Кафе для зустрічей щовівторка 9:30–11:00, безкоштовна кава. Організовують громада і церкви Остермундігена.",
         en="Meeting café every Tuesday 9:30–11:00 with free coffee, run by the municipality and local churches.",
         de="Begegnungscafé jeden Dienstag 9.30–11 Uhr mit Gratis-Kaffee, von Gemeinde und Kirchen Ostermundigen.",
         languages=["de"], services=["Кава та спілкування"], hours=hours([TUE], "09:30", "11:00"), source="https://www.ukraine-hilfe-bern.ch/angebote"),
    # --- Ukrainian kitchen
    dict(key="kozak-buvette", name="Kozak Buvette", type="community", category="restaurant",
         street="Viaduktstrasse", number="10", zip="4051", city="Basel", canton="BS",
         query="Viaduktstrasse 10, 4051 Basel",
         uk="Українська кухня в Markthalle Basel: борщ, вареники, все готують на місці.",
         en="Ukrainian kitchen in Basel's Markthalle: borscht, varenyky, made from scratch.",
         de="Ukrainische Küche in der Markthalle Basel: Borschtsch, Wareniki, frisch zubereitet.",
         phone="+41 78 313 50 42", website="https://www.kozakbuvette.ch/",
         languages=["uk", "de", "en"], services=["Українська кухня"],
         hours=hours([MON, TUE, WED, THU, FRI, SAT], "11:30", "14:00"), source="https://www.kozakbuvette.ch/"),
    dict(key="alexander-basel", name="Restaurant Alexander", type="community", category="restaurant",
         street="Riehenring", number="85", zip="4058", city="Basel", canton="BS",
         query="Riehenring 85, 4058 Basel",
         uk="Ресторан біля Messeplatz з українськими стравами в меню: борщ, вареники.",
         en="Restaurant by Messeplatz with Ukrainian dishes on the menu: borscht, varenyky.",
         de="Restaurant beim Messeplatz mit ukrainischen Spezialitäten: Borschtsch, Wareniki.",
         website="https://www.restaurant-alexander-bs.ch/", languages=["uk", "de"], services=["Українська кухня"],
         source="https://www.polizeinews.ch/restaurant-alexander-bietet-eine-fusion-ukrainischer-spezialitaeten-in-basel/"),
    dict(key="abend-kyiv", name="Abend.Kyiv", type="community", category="restaurant",
         street="Limmatquai", number="88", zip="8001", city="Zürich", canton="ZH",
         query="Limmatquai 88, 8001 Zürich",
         uk="Українська кухня на Limmatquai: борщ, вареники, деруни. Відкрито ввечері, зазвичай з четверга по суботу.",
         en="Ukrainian kitchen on Limmatquai: borscht, varenyky, deruny. Evenings, usually Thursday to Saturday.",
         de="Ukrainische Küche am Limmatquai: Borschtsch, Wareniki, Deruny. Abends, meist Donnerstag bis Samstag.",
         languages=["uk", "de"], services=["Українська кухня"],
         source="https://warenyky.ch/de/blog/2023/09/28/ukrainisches-essen-in-zurich-bestellen/"),
    # --- Shops that stock Ukrainian products
    dict(key="lakomka-stansstad", name="Lakomka Stansstad", type="community", category="grocery_store",
         street="Zielmatte", number="2", zip="6362", city="Stansstad", canton="NW",
         query="Zielmatte 2, 6362 Stansstad",
         uk="Східноєвропейські продукти, зокрема українські.", en="Eastern European groceries, including Ukrainian products.",
         de="Osteuropäische Lebensmittel, auch ukrainische Produkte.",
         website="https://www.facebook.com/LakomkaStansstad/", languages=["uk", "de"], services=["Українські продукти"], source="https://www.sidebase.ch/ukgeschaefte/"),
    dict(key="slavic-shop-winterthur", name="Slavic Shop", type="community", category="grocery_store",
         street="Kanzleistrasse", number="23", zip="8405", city="Winterthur", canton="ZH",
         query="Kanzleistrasse 23, 8405 Winterthur",
         uk="Слов'янські продукти, зокрема українські.", en="Slavic groceries, including Ukrainian products.",
         de="Slawische Lebensmittel, auch ukrainische Produkte.",
         website="https://www.slavic-shop.ch/", languages=["uk", "de"], services=["Українські продукти"], source="https://www.sidebase.ch/ukgeschaefte/"),
    dict(key="gastro-tour-luzern", name="Gastro Tour", type="community", category="grocery_store",
         street="Moosstrasse", number="2", zip="6003", city="Luzern", canton="LU",
         query="Moosstrasse 2, 6003 Luzern",
         uk="Продукти з України, Польщі, Балтії та інших країн Східної Європи.", en="Groceries from Ukraine, Poland, the Baltics and other Eastern European countries.",
         de="Lebensmittel aus der Ukraine, Polen, dem Baltikum und weiteren osteuropäischen Ländern.",
         website="https://gastro-tour.ch/shop/", languages=["uk", "de"], services=["Українські продукти"], source="https://www.sidebase.ch/ukgeschaefte/"),
    dict(key="berezka-geneve", name="La Berezka", type="community", category="grocery_store",
         street="Rue de la Terrassière", number="48", zip="1207", city="Genève", canton="GE",
         query="Rue de la Terrassière 48, 1207 Genève",
         uk="Східноєвропейські продукти в Женеві, зокрема українські.", en="Eastern European groceries in Geneva, including Ukrainian products.",
         de="Osteuropäische Lebensmittel in Genf, auch ukrainische Produkte.",
         website="https://www.facebook.com/Laberezka/", languages=["uk", "fr"], services=["Українські продукти"], source="https://www.sidebase.ch/ukgeschaefte/"),
    # --- Germany and Austria
    dict(key="emb-berlin", country="DE", region="DE-BE", canton="", name="Посольство України в Німеччині", type="government", category="embassy", street="Albrechtstraße", number="26", zip="10117", city="Berlin", query="Albrechtstraße 26, 10117 Berlin", uk="Консульські послуги для громадян України: паспорти, довідки, нотаріальні дії. Консульський відділ: +49 30 28 88 71 70.", en="Consular services for Ukrainian citizens: passports, certificates, notarial acts. Consular section: +49 30 28 88 71 70.", de="Konsularische Dienste für ukrainische Staatsangehörige: Pässe, Bescheinigungen, Beglaubigungen. Konsularabteilung: +49 30 28 88 71 70.", source="https://www.auswaertiges-amt.de/de/service/laender/ukraine-node/vertretungenukraine-201950", phone='+49 30 288 871 28', website='https://germany.mfa.gov.ua', languages=['uk', 'de'], services=['Паспорти', 'Консульські довідки', 'Нотаріальні дії']),
    dict(key="gk-duesseldorf", country="DE", region="DE-NW", canton="", name="Генеральне консульство України в Дюссельдорфі", type="government", category="embassy", street="Luisenstraße", number="9", zip="40215", city="Düsseldorf", query="Luisenstraße 9, 40215 Düsseldorf", uk="Паспорти, консульський облік, довідки та нотаріальні дії. Прийом за попереднім записом.", en="Passports, consular registration, certificates and notarial acts. By appointment.", de="Pässe, konsularische Registrierung, Bescheinigungen und Beglaubigungen. Nach Terminvereinbarung.", source="https://www.auswaertiges-amt.de/de/service/laender/ukraine-node/vertretungenukraine-201950", phone='+49 211 93 65 42 11', languages=['uk', 'de'], services=['Паспорти', 'Консульський облік']),
    dict(key="gk-frankfurt", country="DE", region="DE-HE", canton="", name="Генеральне консульство України в Франкфурті-на-Майні", type="government", category="embassy", street="Vilbeler Straße", number="29", zip="60313", city="Frankfurt am Main", query="Vilbeler Straße 29, 60313 Frankfurt am Main", uk="Паспорти, консульський облік, довідки та нотаріальні дії. Прийом за попереднім записом.", en="Passports, consular registration, certificates and notarial acts. By appointment.", de="Pässe, konsularische Registrierung, Bescheinigungen und Beglaubigungen. Nach Terminvereinbarung.", source="https://www.auswaertiges-amt.de/de/service/laender/ukraine-node/vertretungenukraine-201950", phone='+49 69 297 209 20', languages=['uk', 'de'], services=['Паспорти', 'Консульський облік']),
    dict(key="gk-hamburg", country="DE", region="DE-HH", canton="", name="Генеральне консульство України в Гамбурзі", type="government", category="embassy", street="Mundsburger Damm", number="1", zip="22087", city="Hamburg", query="Mundsburger Damm 1, 22087 Hamburg", uk="Паспорти, консульський облік, довідки та нотаріальні дії. Прийом за попереднім записом.", en="Passports, consular registration, certificates and notarial acts. By appointment.", de="Pässe, konsularische Registrierung, Bescheinigungen und Beglaubigungen. Nach Terminvereinbarung.", source="https://www.auswaertiges-amt.de/de/service/laender/ukraine-node/vertretungenukraine-201950", phone='+49 40 229 498 10', languages=['uk', 'de'], services=['Паспорти', 'Консульський облік']),
    dict(key="gk-muenchen", country="DE", region="DE-BY", canton="", name="Генеральне консульство України в Мюнхені", type="government", category="embassy", street="Riedenburger Straße", number="2", zip="81633", city="München", query="Riedenburger Straße 2, 81633 München", uk="Паспорти, консульський облік, довідки та нотаріальні дії. Прийом за попереднім записом.", en="Passports, consular registration, certificates and notarial acts. By appointment.", de="Pässe, konsularische Registrierung, Bescheinigungen und Beglaubigungen. Nach Terminvereinbarung.", source="https://www.auswaertiges-amt.de/de/service/laender/ukraine-node/vertretungenukraine-201950", phone='+49 89 55 27 37 18', languages=['uk', 'de'], services=['Паспорти', 'Консульський облік'], zips=['81633', '81677']),
    dict(key="ugcc-berlin", country="DE", region="DE-BE", canton="", name="Українська греко-католицька парафія св. Миколая (Берлін)", type="community", category="religious_center", street="Waldstraße", number="11", zip="12487", city="Berlin", query="Waldstraße 11, 12487 Berlin", uk="Літургія українською щонеділі о 9:00 і 11:00 у церкві St. Johannes Evangelist.", en="Ukrainian liturgy every Sunday at 9:00 and 11:00 at St. Johannes Evangelist church (St. Nicholas parish).", de="Ukrainische Liturgie jeden Sonntag um 9 und 11 Uhr in der Kirche St. Johannes Evangelist (Pfarrei St. Nikolaus).", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", email='ugcc.berlin@gmail.com', languages=['uk'], services=['Богослужіння українською'], hours=hours([SUN], "09:00", "12:30")),
    dict(key="ocu-berlin", country="DE", region="DE-BE", canton="", name="Парафія св. Андрія Первозванного ПЦУ (Берлін)", type="community", category="religious_center", street="Grazer Platz", number="4", zip="12157", city="Berlin", query="Nathanael-Kirche, Grazer Platz, Berlin", uk="Православна церква України в Берліні. Служба щонеділі в Nathanael-Kirche: листопад–березень о 10:00, квітень–жовтень о 12:00.", en="Orthodox Church of Ukraine in Berlin. Sunday service at Nathanael-Kirche: 10:00 from November to March, 12:00 from April to October.", de="Orthodoxe Kirche der Ukraine in Berlin. Sonntagsgottesdienst in der Nathanael-Kirche: November–März 10 Uhr, April–Oktober 12 Uhr.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk'], services=['Богослужіння українською']),
    dict(key="ua-school-berlin", country="DE", region="DE-BE", canton="", name="Українська школа в Берліні", type="education", category="school", street="Am Treptower Park", number="28-30", zip="12435", city="Berlin", query="Am Treptower Park 28, 12435 Berlin", uk="Школа з 2017 року: діти вчаться читати, писати й навчатися українською.", en="Since 2017: children learn to read, write and study in Ukrainian.", de="Seit 2017: Kinder lernen auf Ukrainisch zu lesen, schreiben und lernen.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", email='ua.school.berlin@gmail.com', languages=['uk'], services=['Українська школа']),
    dict(key="plast-berlin", country="DE", region="DE-BE", canton="", name="Пласт Берлін", type="community", category="community_center", street="Wilhelmstraße", number="116", zip="10963", city="Berlin", query="Wilhelmstraße 116, 10963 Berlin", uk="Українська скаутська організація для дітей і молоді, діє в Берліні з 2017 року.", en="Ukrainian scouting for children and teens, active in Berlin since 2017.", de="Ukrainische Pfadfinder für Kinder und Jugendliche, seit 2017 in Berlin.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", email='plast.berlin@gmail.com', languages=['uk'], services=['Скаутинг', 'Табори']),
    dict(key="alliance-berlin", country="DE", region="DE-BE", canton="", name="Альянс українських організацій · Interkulturelles Haus", type="community", category="community_center", street="Schönfließer Straße", number="7", zip="10439", city="Berlin", query="Schönfließer Straße 7, 10439 Berlin", uk="Об'єднання 22 українських організацій: зустрічі, воркшопи, психосоціальна підтримка, консультації для біженців.", en="Alliance of 22 Ukrainian organisations: meetups, workshops, psychosocial support and advice for refugees.", de="Zusammenschluss von 22 ukrainischen Organisationen: Treffen, Workshops, psychosoziale Unterstützung, Beratung.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", website='https://ukr-alliance.de', languages=['uk', 'de'], services=['Зустрічі', 'Консультації', 'Психологічна підтримка']),
    dict(key="vitsche-bedryk", country="DE", region="DE-BE", canton="", name="Vitsche · дитячий центр «Бедрик»", type="community", category="community_center", street="Skalitzer Straße", number="80", zip="10997", city="Berlin", query="Skalitzer Straße 80, 10997 Berlin", uk="Простір української молодіжної організації Vitsche та дитячий центр «Бедрик» для дітей-біженців і їхніх мам.", en="Home of the Ukrainian youth group Vitsche and the Bedryk children's centre for refugee kids and their mothers.", de="Räume der ukrainischen Jugendorganisation Vitsche und des Kinderzentrums Bedryk für geflüchtete Kinder und Mütter.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Дитячий центр', 'Події громади']),
    dict(key="ua-nest-berlin", country="DE", region="DE-BE", canton="", name="UA Nest Berlin", type="community", category="community_center", street="Levetzowstraße", number="13", zip="10555", city="Berlin", query="Levetzowstraße 13, 10555 Berlin", uk="Хаб і коворкінг для українських правозахисників і громадських активістів.", en="Hub and co-working space for Ukrainian human rights defenders and civic activists.", de="Hub und Co-Working für ukrainische Menschenrechtler:innen und Aktivist:innen.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", website='https://uanest.berlin/', languages=['uk', 'en'], services=['Коворкінг', 'Події']),
    dict(key="spiel-sprach-cafe", country="DE", region="DE-BE", canton="", name="Spiel-Sprach-Café", type="community", category="community_cafe", street="Treskowallee", number="78", zip="10318", city="Berlin", query="Treskowallee 78, 10318 Berlin", uk="Кафе для зустрічей і розмовної мови для українських сімей.", en="Meeting and language café for Ukrainian families.", de="Begegnungs- und Sprachcafé für ukrainische Familien.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Кава та спілкування', 'Розмовна німецька']),
    dict(key="ua-institut", country="DE", region="DE-BE", canton="", name="Український інститут у Німеччині", type="community", category="cultural_center", street="Friedrichstraße", number="95", zip="10117", city="Berlin", query="Friedrichstraße 95, 10117 Berlin", uk="Перше закордонне представництво Українського інституту: виставки, лекції, кіно й музика.", en="The Ukrainian Institute's first office abroad: exhibitions, talks, film and music.", de="Erste Auslandsvertretung des Ukrainischen Instituts: Ausstellungen, Vorträge, Film und Musik.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de', 'en'], services=['Культурні події']),
    dict(key="kinoklub-berlin", country="DE", region="DE-BE", canton="", name="Український кіноклуб Берліна · Kino Brotfabrik", type="community", category="cultural_center", street="Caligariplatz", number="1", zip="13086", city="Berlin", query="Caligariplatz 1, 13086 Berlin", uk="Регулярні покази українського кіно в кінотеатрі Brotfabrik.", en="Regular screenings of Ukrainian films at the Brotfabrik cinema.", de="Regelmäßige Vorführungen ukrainischer Filme im Kino Brotfabrik.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk'], services=['Українське кіно']),
    dict(key="ua-theater-berlin", country="DE", region="DE-BE", canton="", name="Український театр Берліна", type="community", category="cultural_center", street="Andreasstraße", number="72", zip="10243", city="Berlin", query="Andreasstraße 72, 10243 Berlin", uk="Вистави українською. Тут же репетирує хор «Українська капела в Берліні».", en="Plays in Ukrainian; the choir Ukrainian Chapel in Berlin rehearses here too.", de="Theater auf Ukrainisch; hier probt auch der Chor Ukrainische Kapelle in Berlin.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", email='ua.theater.berlin@gmail.com', languages=['uk'], services=['Театр', 'Хор']),
    dict(key="kultura-club", country="DE", region="DE-BE", canton="", name="Kul'tura Club · Amerika-Gedenkbibliothek", type="community", category="library", street="Blücherplatz", number="1", zip="10961", city="Berlin", query="Blücherplatz 1, 10961 Berlin", uk="Український клуб культури в центральній бібліотеці Берліна.", en="Ukrainian culture club at Berlin's central library.", de="Ukrainischer Kulturclub in der Amerika-Gedenkbibliothek.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Книжковий клуб', 'Культурні події']),
    dict(key="karow-library", country="DE", region="DE-BE", canton="", name="Українські книжки · Stadtteilbibliothek Karow", type="education", category="library", street="Achillesstraße", number="77", zip="13125", city="Berlin", query="Achillesstraße 77, 13125 Berlin", uk="Бібліотека, де можна безкоштовно позичити книжки українською.", en="Library lending books in Ukrainian for free.", de="Bibliothek mit ukrainischen Büchern zum Ausleihen.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Книжки українською']),
    dict(key="kirschen-berlin", country="DE", region="DE-BE", canton="", name="Die mit den Kirschen", type="community", category="restaurant", street="Wielandstraße", number="38", zip="10629", city="Berlin", query="Wielandstraße 38, 10629 Berlin", uk="Сучасна українська кухня в Шарлоттенбурзі, гості хвалять борщ.", en="Modern Ukrainian kitchen in Charlottenburg, praised for its borscht.", de="Moderne ukrainische Küche in Charlottenburg, bekannt für Borschtsch.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Українська кухня']),
    dict(key="slava-berlin", country="DE", region="DE-BE", canton="", name="Slava Berlin!", type="community", category="restaurant", street="Wrangelstraße", number="43", zip="10997", city="Berlin", query="Wrangelstraße 43, 10997 Berlin", uk="Український соулфуд і наливки в Кройцберзі.", en="Ukrainian soul food and nalyvky in Kreuzberg.", de="Ukrainisches Soulfood und Nalivki in Kreuzberg.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Українська кухня']),
    dict(key="drei-elefanten", country="DE", region="DE-BE", canton="", name="Drei Elefanten · Fresh Ukrainian Soulfood", type="community", category="restaurant", street="Donaustraße", number="104", zip="12043", city="Berlin", query="Donaustraße 104, 12043 Berlin", uk="Український соулфуд у Нойкельні, є веганський борщ.", en="Ukrainian soul food in Neukölln, including vegan borscht.", de="Ukrainisches Soulfood in Neukölln, auch veganer Borschtsch.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Українська кухня']),
    dict(key="odessa-mama", country="DE", region="DE-BE", canton="", name="Odessa Mama", type="community", category="restaurant", street="Innsbrucker Platz", number="3", zip="10827", city="Berlin", query="Innsbrucker Platz 3, 10827 Berlin", uk="Ресторан одеської кухні.", en="Restaurant with Odesa cuisine.", de="Restaurant mit Odessaer Küche.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Українська кухня']),
    dict(key="kueche-ua", country="DE", region="DE-BE", canton="", name="Küche UA · Markthalle Neun", type="community", category="restaurant", street="Eisenbahnstraße", number="42/43", zip="10997", city="Berlin", query="Eisenbahnstraße 42, 10997 Berlin", uk="Українська кухня щочетверга 17:00–22:00 у Markthalle Neun.", en="Ukrainian food every Thursday 17:00–22:00 at Markthalle Neun.", de="Ukrainische Küche jeden Donnerstag 17–22 Uhr in der Markthalle Neun.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Українська кухня'], hours=hours([THU], "17:00", "22:00")),
    dict(key="paska-l", country="DE", region="DE-BE", canton="", name="Paska.L", type="community", category="restaurant", street="Kollwitzstraße", number="66", zip="10435", city="Berlin", query="Kollwitzstraße 66, 10435 Berlin", uk="Український ресторан у Пренцлауер-Берзі.", en="Ukrainian restaurant in Prenzlauer Berg.", de="Ukrainisches Restaurant im Prenzlauer Berg.", source="https://ukrainet.eu/wp-content/uploads/2025/02/Ukrainische-Orte-in-Berlin_Die-Karte_2025.pdf", languages=['uk', 'de'], services=['Українська кухня']),
    dict(key="ugcc-muenchen", country="DE", region="DE-BY", canton="", name="Кафедральний собор УГКЦ Покрови і св. Андрія (Мюнхен)", type="community", category="religious_center", street="Schönstraße", number="55", zip="81543", city="München", query="Schönstraße 55, 81543 München", uk="Кафедральний собор Апостольського екзархату УГКЦ у Німеччині та Скандинавії. Літургія щонеділі.", en="Cathedral of the Ukrainian Greek-Catholic exarchate for Germany and Scandinavia. Sunday liturgy.", de="Kathedrale des ukrainischen griechisch-katholischen Exarchats für Deutschland und Skandinavien. Sonntagsliturgie.", source="https://www.ukr-kirche.de/seite/561733/kontakt.html", phone='+49 89 651 29 09 0', email='ugkkm@t-online.de', website='https://www.ukr-kirche.de', languages=['uk'], services=['Богослужіння українською']),
    dict(key="ufu-muenchen", country="DE", region="DE-BY", canton="", name="Український вільний університет", type="education", category="university", street="Barellistraße", number="9a", zip="80638", city="München", query="Barellistraße 9, 80638 München", uk="Український університет у Мюнхені з 1921 року: навчання, лекції, події громади. Секретаріат Пн–Пт 9:00–13:00.", en="Ukrainian university in Munich since 1921: studies, lectures, community events. Office Mon–Fri 9:00–13:00.", de="Ukrainische Universität in München seit 1921: Studium, Vorträge, Community-Veranstaltungen. Sekretariat Mo–Fr 9–13 Uhr.", source="https://www.ufu-muenchen.de/kontakt/", website='https://www.ufu-muenchen.de', languages=['uk', 'de'], services=['Навчання', 'Лекції', 'Події'], hours=hours([MON, TUE, WED, THU, FRI], "09:00", "13:00")),
    dict(key="ruta-muenchen", country="DE", region="DE-BY", canton="", name="Ruta", type="community", category="restaurant", street="Tulbeckstraße", number="9", zip="80339", city="München", query="Tulbeckstraße 9, 80339 München", uk="Українське бістро у Вестенді: традиційні страви з сучасними акцентами.", en="Ukrainian bistro in Westend: traditional dishes with a modern touch.", de="Ukrainisches Bistro im Westend: traditionelle Gerichte, modern interpretiert.", source="https://www.cremeguides.com/muenchen/restaurant-ruta/", languages=['uk', 'de'], services=['Українська кухня']),
    dict(key="mavka-frankfurt", country="DE", region="DE-HE", canton="", name="Mavka", type="community", category="restaurant", street="Wasgaustraße", number="19A", zip="", city="Frankfurt am Main", query="Wasgaustraße 19, Frankfurt am Main", uk="Сучасний український ресторан, вареники в меню. Ср–Пт 18:00–22:00, Сб 13:00–22:00, Нд 11:00–21:00.", en="Modern Ukrainian restaurant with varenyky. Wed–Fri 18:00–22:00, Sat 13:00–22:00, Sun 11:00–21:00.", de="Modernes ukrainisches Restaurant mit Wareniki. Mi–Fr 18–22, Sa 13–22, So 11–21 Uhr.", source="https://www.mavka-ua.com/", website='https://www.mavka-ua.com/', languages=['uk', 'de'], services=['Українська кухня'], hours=hours([WED, THU, FRI], "18:00", "22:00") + hours([SAT], "13:00", "22:00") + hours([SUN], "11:00", "21:00")),
    dict(key="emb-wien", country="AT", region="AT-9", canton="", name="Посольство України в Австрії", type="government", category="embassy", street="Naaffgasse", number="23", zip="1180", city="Wien", query="Naaffgasse 23, 1180 Wien", uk="Консульські послуги для громадян України в Австрії: паспорти, довідки, нотаріальні дії.", en="Consular services for Ukrainian citizens in Austria: passports, certificates, notarial acts.", de="Konsularische Dienste für ukrainische Staatsangehörige in Österreich: Pässe, Bescheinigungen, Beglaubigungen.", source="https://austria.mfa.gov.ua/de", website='https://austria.mfa.gov.ua', languages=['uk', 'de'], services=['Паспорти', 'Консульські довідки']),
    dict(key="st-barbara-wien", country="AT", region="AT-9", canton="", name="Церква св. Варвари · Barbareum (УГКЦ Відень)", type="community", category="religious_center", street="Postgasse", number="8", zip="1010", city="Wien", query="Barbarakirche, Postgasse, Wien", uk="Головна українська греко-католицька церква Австрії й центр громади: богослужіння українською, простір Barbareum для зустрічей і допомоги.", en="Main Ukrainian Greek-Catholic church in Austria and a community hub: Ukrainian liturgy and the Barbareum space for meetups and aid.", de="Hauptkirche der ukrainischen Griechisch-Katholischen in Österreich und Community-Zentrum: Liturgie auf Ukrainisch, Barbareum für Treffen und Hilfe.", source="https://www.geschichtewiki.wien.gv.at/Barbarakirche", languages=['uk', 'de'], services=['Богослужіння українською', 'Простір громади']),
    dict(key="ukr-schule-wien", country="AT", region="AT-9", canton="", name="Українська суботня школа у Відні", type="education", category="school", street="Beethovenplatz", number="1", zip="1010", city="Wien", query="Beethovenplatz 1, 1010 Wien", uk="Заняття щосуботи та щонеділі в будівлі Akademisches Gymnasium, а також гуртки й курси.", en="Classes every Saturday and Sunday at the Akademisches Gymnasium, plus clubs and courses.", de="Unterricht jeden Samstag und Sonntag im Akademischen Gymnasium, dazu Kurse und Workshops.", source="https://ukr-schule.at/de/schule", website='https://ukr-schule.at', languages=['uk'], services=['Українська школа', 'Гуртки']),
    dict(key="elviras-wien", country="AT", region="AT-9", canton="", name="Elvira's", type="community", category="restaurant", street="Seidlgasse", number="39", zip="1030", city="Wien", query="Seidlgasse 39, 1030 Wien", uk="Традиційна українська кухня: борщ, вареники, голубці. Пн–Пт 11:30–22:30, Сб 17:00–22:30.", en="Traditional Ukrainian kitchen: borscht, varenyky, holubtsi. Mon–Fri 11:30–22:30, Sat 17:00–22:30.", de="Traditionelle ukrainische Küche: Borschtsch, Wareniki, Holubzi. Mo–Fr 11.30–22.30, Sa 17–22.30 Uhr.", source="https://elvirasrestaurant.at/", phone='+43 1 890 80 81', website='https://elvirasrestaurant.at/', languages=['uk', 'de'], services=['Українська кухня'], hours=hours([MON, TUE, WED, THU, FRI], "11:30", "22:30") + hours([SAT], "17:00", "22:30")),
]

def _search(params, country):
    url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode({**params, "format": "json", "limit": 1, "countrycodes": country.lower()})
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    time.sleep(1.1)
    return data[0] if data else None

def _inside(label, zips, city):
    # The postcode decides when the hit has one; "Zürich" alone also matches the canton name.
    codes = re.findall(r"\b\d{4,5}\b", label)
    if not zips:
        return city in label.lower()
    return bool(set(zips) & set(codes)) if codes else city in label.lower()

def geocode(e):
    """Free-text first (it recognises churches and halls by name), then a structured street/city/zip
    lookup. Either way the hit must lie in the entry's city or postcode, so a same-named street in
    another town never slips through."""
    city = e["city"].split()[0].lower()
    country = e.get("country", "CH")
    zips = e.get("zips", [e["zip"]] if e["zip"] else [])
    structured = {"street": f"{e['number']} {e['street']}", "city": e["city"]}
    if e["zip"]:
        structured["postalcode"] = e["zip"]
    for params in ({"q": e["query"]}, structured):
        hit = _search(params, country)
        # A label that starts with the street name is the street's centre, not the building.
        street_only = hit and hit["display_name"].split(",")[0].strip() == e["street"]
        if hit and not street_only and _inside(hit["display_name"], zips, city):
            return float(hit["lat"]), float(hit["lon"]), hit["display_name"]
    return None

out = {"CH": [], "DE": [], "AT": []}
skipped = []
for e in ENTRIES:
    hit = geocode(e)
    if hit is None:
        # A pin on the wrong building is worse than no pin: leave it out and say so.
        skipped.append(f"{e['key']} ({e['street']} {e['number']}, {e['zip']} {e['city']})")
        continue
    lat, lon, label = hit
    country = e.get("country", "CH")
    if not e["zip"]:
        e["zip"] = (re.findall(r"\b\d{4,5}\b", label) or [""])[-1]
    print(f"{country} {e['key']:28} {lat:.6f},{lon:.6f}  {label[:80]}")
    # Swiss places carry a canton; German and Austrian ones keep their region in subdivisionCode
    # (DE-BE, AT-9) and leave the Swiss-only canton field to the decoder's default, like places-DE.json.
    region = e["canton"] if country == "CH" else e["region"]
    place = {
        "id": e.get("id") or str(uuid.uuid5(NS, e["key"])),
        "name": e["name"], "type": e["type"], "category": e["category"],
        "audience": "ukrainian",
        "description": e["uk"],
        "descriptions": {"uk": e["uk"], "en": e["en"], "de": e["de"]},
        "address": {"street": e["street"], "houseNumber": e["number"], "postalCode": e["zip"], "city": e["city"],
                    "canton": e["canton"] if country == "CH" else "ZH"},
        "coordinate": {"latitude": round(lat, 6), "longitude": round(lon, 6)},
        "countryCode": country, "subdivisionCode": region,
        "openingHours": e.get("hours", []), "languages": e["languages"], "services": e["services"],
        "isAccessible": False, "reviewCount": 0, "source": e["source"],
        "verifiedAt": "2026-10-28T00:00:00Z",
    }
    if country == "CH":
        place["canton"] = e["canton"]
    for k in ("phone", "email", "website"):
        if e.get(k):
            place[{"phone": "phoneNumber"}.get(k, k)] = e[k]
    out[country].append(place)

for country, places in out.items():
    path = f"{sys.argv[1]}/places_ukrainian_{country.lower()}.json"
    json.dump(places, open(path, "w"), ensure_ascii=False, indent=1)
    print(f"wrote {len(places)} places to {path}")
if skipped:
    print("skipped, no exact match in OpenStreetMap:\n  " + "\n  ".join(skipped))
