# Doseday — App Store metadata (20 locales, matching the app's languages)

Paste each block into App Store Connect → your app → the version's localization. Limits: name 30, subtitle 30, keywords 100 characters (comma-separated, no spaces). Every description must end with the Terms of Use and Privacy Policy links shown for its locale.

Locales match the app's String Catalog: en, en-GB, en-AU, en-CA, de, fr, fr-CA, es, es-MX, it, pt-BR, ja, ko, ar, tr, zh-Hans, zh-Hant, id, hi, ru. Removed (app is not translated into them): nl-NL, sv, da, no, pl. Added: zh-Hans, zh-Hant, id, hi, ru.

## Keyword research (wowkeywords.com keyword checker, App Store, checked 2026-11-24)

Volume / difficulty (0–100). Only the notable results are listed.

| Keyword | Where it matters | Volume · Difficulty |
|---|---|---|
| glp-1 | US 60·36, BR 55·83, CA 44, MX 40, AU 36, UK 35, FR 31, ES 30, IT 28, DE 27, TW 27, TR 26, IN 23, SA 20, CN 16, KR 15 | Has volume everywhere: kept in every name |
| glp-1 tracker | US 60·57, CA 38, UK 35, AU 31, FR (suivi GLP-1) 27, BR (controle GLP-1) 21, IT 16 | Target |
| peptide tracker | US 46·55, AU 33, UK 29, CA 29, DE (Peptid-Tracker) 15·42, IN 14, BR 13 | **New: added to the name** |
| peptide | US 46, AU 32, CA 29, UK 27, BR (peptídeos) 20, DE 15, FR 14, MX 11 | Target |
| shot tracker | US 41·29, CA 24, UK 23, AU 23 | Easy: "Shot" in subtitle |
| injection | US 25·40, TW 注射 25, UK 17, FR 17, CA 14, CN 注射 12 | Target |
| injection tracker | US 16·40, KR 주사 관리 12, CA 10, FR suivi injections 10·18 | Target |
| weight loss injection | KR 다이어트 주사 22, DE Abnehmspritze 15, BR caneta emagrecedora 8, TW 減肥針 8 | Used in ko/de/zh-Hant/pt-BR |
| semaglutide | US 27·66, CA 12, UK 9, CN 司美格鲁肽 6 | Keywords field |
| tirzepatide | BR 28·62 (English spelling!), US 5, TR 4 | Keywords field; English spelling added for pt-BR/tr |
| medication / dose reminder | BR 46, FR 45, IT 44, MX 42, KR 약 알림 39, TW 29 | Difficulty 57–91: only in keywords/subtitle, not name |
| weight loss tracker / weight log | US 66·95, JP 体重記録 68·100, KR 56·100 | Too hard to target in name; single words kept in keywords |

**Strategy:** name = brand + the two best keywords (`GLP-1` + `Peptide Tracker` or the local equivalent); subtitle adds injection / shot / dose / weight; keywords hold everything else. Apple combines words across name, subtitle and keywords, so no word is repeated.

**Brand names left out on purpose:** Ozempic, Wegovy, Mounjaro and Zepbound are trademarks and commonly cause rejection (Guideline 2.3.7 / 5.2.1). The old ko keyword `위고비` (Wegovy) was removed for this reason. Generic drug names are fine.

**Translations** were written by AI: have a native speaker check them before going live, especially ja, ko, ar-SA, tr, zh-Hans, zh-Hant, hi, ru, id.

## en-US — United States

- **Name** (30): `Doseday: GLP-1 Peptide Tracker`
- **Subtitle** (29): `Shot Log & Injection Reminder`
- **Keywords** (97): `semaglutide,tirzepatide,glp1,weight,loss,dose,pen,site,rotation,side,effects,diary,bmi,medication`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Terms of Use: https://doseday.vercel.app/terms
  Privacy Policy: https://doseday.vercel.app/privacy
  ```

## en-GB — United Kingdom, Ireland

- **Name** (30): `Doseday: GLP-1 Peptide Tracker`
- **Subtitle** (29): `Shot Log & Injection Reminder`
- **Keywords** (98): `jab,semaglutide,tirzepatide,glp1,weight,loss,dose,pen,site,rotation,side,effects,diary,bmi,journal`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Terms of Use: https://doseday.vercel.app/terms
  Privacy Policy: https://doseday.vercel.app/privacy
  ```

## en-CA — Canada

- **Name** (30): `Doseday: GLP-1 Peptide Tracker`
- **Subtitle** (29): `Shot Log & Injection Reminder`
- **Keywords** (97): `semaglutide,tirzepatide,glp1,weight,loss,dose,pen,site,rotation,side,effects,diary,bmi,medication`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Terms of Use: https://doseday.vercel.app/terms
  Privacy Policy: https://doseday.vercel.app/privacy
  ```

## en-AU — Australia, New Zealand

- **Name** (30): `Doseday: GLP-1 Peptide Tracker`
- **Subtitle** (29): `Shot Log & Injection Reminder`
- **Keywords** (98): `jab,semaglutide,tirzepatide,glp1,weight,loss,dose,pen,site,rotation,side,effects,diary,bmi,journal`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Terms of Use: https://doseday.vercel.app/terms
  Privacy Policy: https://doseday.vercel.app/privacy
  ```

## de-DE — Germany, Austria, Switzerland

- **Name** (29): `Doseday: GLP-1 Peptid-Tracker`
- **Subtitle** (30): `Abnehmspritze & Dosis-Tagebuch`
- **Keywords** (97): `semaglutid,tirzepatid,glp1,erinnerung,gewicht,abnehmen,injektion,pen,nebenwirkungen,bmi,protokoll`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Nutzungsbedingungen: https://doseday.vercel.app/terms
  Datenschutzerklärung: https://doseday.vercel.app/privacy
  ```

## fr-FR — France, Belgium, Switzerland

- **Name** (30): `Doseday: Suivi GLP-1 & Peptide`
- **Subtitle** (30): `Injections, rappel dose, poids`
- **Keywords** (97): `sémaglutide,tirzépatide,glp1,piqûre,perte,stylo,effets,secondaires,imc,traitement,minceur,journal`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Conditions d’utilisation: https://doseday.vercel.app/terms
  Politique de confidentialité: https://doseday.vercel.app/privacy
  ```

## fr-CA — Canada (French)

- **Name** (30): `Doseday: Suivi GLP-1 & Peptide`
- **Subtitle** (30): `Injections, rappel dose, poids`
- **Keywords** (97): `sémaglutide,tirzépatide,glp1,piqûre,perte,stylo,effets,secondaires,imc,traitement,minceur,journal`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Conditions d’utilisation: https://doseday.vercel.app/terms
  Politique de confidentialité: https://doseday.vercel.app/privacy
  ```

## es-ES — Spain

- **Name** (25): `Doseday: GLP-1 y Péptidos`
- **Subtitle** (30): `Registro de inyecciones y peso`
- **Keywords** (94): `semaglutida,tirzepatida,glp1,dosis,recordatorio,adelgazar,pluma,efectos,secundarios,imc,diario`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Términos de uso: https://doseday.vercel.app/terms
  Política de privacidad: https://doseday.vercel.app/privacy
  ```

## es-MX — Mexico, Latin America

- **Name** (25): `Doseday: GLP-1 y Péptidos`
- **Subtitle** (30): `Registro de inyecciones y peso`
- **Keywords** (98): `semaglutida,tirzepatida,glp1,dosis,recordatorio,bajar,pluma,efectos,secundarios,imc,diario,control`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Términos de uso: https://doseday.vercel.app/terms
  Política de privacidad: https://doseday.vercel.app/privacy
  ```

## it — Italy

- **Name** (30): `Doseday: Tracker GLP-1 Peptidi`
- **Subtitle** (29): `Diario iniezioni, dosi e peso`
- **Keywords** (97): `semaglutide,tirzepatide,glp1,promemoria,dimagrire,penna,effetti,collaterali,bmi,farmaci,controllo`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Termini d’uso: https://doseday.vercel.app/terms
  Informativa sulla privacy: https://doseday.vercel.app/privacy
  ```

## pt-BR — Brazil

- **Name** (26): `Doseday: GLP-1 e Peptídeos`
- **Subtitle** (27): `Controle de injeções e peso`
- **Keywords** (98): `tirzepatide,semaglutida,tirzepatida,glp1,canetinha,caneta,emagrecedora,emagrecer,lembrete,dose,imc`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Termos de Uso: https://doseday.vercel.app/terms
  Política de Privacidade: https://doseday.vercel.app/privacy
  ```

## ja — Japan

- **Name** (23): `Doseday: GLP-1・ペプチド注射記録`
- **Subtitle** (17): `投与量・体重・副作用をかんたん管理`
- **Keywords** (75): `セマグルチド,チルゼパチド,glp1,ダイエット,リマインダー,ペン,bmi,痩せる,メディカルダイエット,トラッカー,服薬,注射管理,体重記録,肥満`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  利用規約: https://doseday.vercel.app/terms
  プライバシーポリシー: https://doseday.vercel.app/privacy
  ```

## ko — South Korea

- **Name** (25): `Doseday: GLP-1 다이어트 주사 기록`
- **Subtitle** (17): `약 알림·용량·체중·부작용 관리`
- **Keywords** (66): `세마글루타이드,티르제파타이드,glp1,펜,비만,bmi,체중감량,트래커,복약,펩타이드,주사관리,투약,체중기록,다이어트기록`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  이용약관: https://doseday.vercel.app/terms
  개인정보 처리방침: https://doseday.vercel.app/privacy
  ```

## ar-SA — Saudi Arabia, UAE, Middle East

- **Name** (21): `Doseday: متابعة GLP-1`
- **Subtitle** (21): `الحقن والجرعات والوزن`
- **Keywords** (94): `سيماجلوتايد,تيرزيباتيد,glp1,تخسيس,إبرة,تذكير,قلم,أعراض,جانبية,مؤشر,كتلة,الجسم,رشاقة,ببتيد,دواء`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  شروط الاستخدام: https://doseday.vercel.app/terms
  سياسة الخصوصية: https://doseday.vercel.app/privacy
  ```

## tr — Türkiye

- **Name** (28): `Doseday: GLP-1 Peptit Takibi`
- **Subtitle** (23): `Enjeksiyon, doz ve kilo`
- **Keywords** (96): `semaglutid,tirzepatid,tirzepatide,glp1,zayıflama,iğne,hatırlatıcı,kalem,yan,etki,bmi,günlük,ilaç`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Kullanım Koşulları: https://doseday.vercel.app/terms
  Gizlilik Politikası: https://doseday.vercel.app/privacy
  ```

## zh-Hans — China mainland, Singapore

- **Name** (18): `Doseday: GLP-1注射记录`
- **Subtitle** (15): `司美格鲁肽减重针剂量与体重管理`
- **Keywords** (58): `替尔泊肽,glp1,减肥针,减肥,打针,提醒,副作用,体重记录,bmi,多肽,注射笔,用药提醒,减肥记录,瘦身,减脂`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  使用条款: https://doseday.vercel.app/terms
  隐私政策: https://doseday.vercel.app/privacy
  ```

## zh-Hant — Taiwan, Hong Kong

- **Name** (21): `Doseday: GLP-1減肥針注射紀錄`
- **Subtitle** (13): `劑量提醒、體重與副作用追蹤`
- **Keywords** (61): `司美格魯肽,替爾泊肽,glp1,減重,打針,吃藥提醒,bmi,胜肽,注射筆,體重紀錄,瘦身,用藥,減肥記錄,體重管理,減脂`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  使用條款: https://doseday.vercel.app/terms
  隱私權政策: https://doseday.vercel.app/privacy
  ```

## id — Indonesia, Malaysia

- **Name** (29): `Doseday: Catatan Suntik GLP-1`
- **Subtitle** (29): `Pengingat dosis & berat badan`
- **Keywords** (98): `semaglutide,tirzepatide,glp1,diet,turun,suntikan,pena,efek,samping,bmi,jurnal,peptida,obat,pelacak`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Ketentuan Penggunaan: https://doseday.vercel.app/terms
  Kebijakan Privasi: https://doseday.vercel.app/privacy
  ```

## hi — India

- **Name** (30): `Doseday: GLP-1 इंजेक्शन ट्रैकर`
- **Subtitle** (25): `डोज़ रिमाइंडर और वज़न लॉग`
- **Keywords** (85): `peptide,semaglutide,tirzepatide,glp1,वजन,घटाना,दवा,खुराक,सुई,पेन,बीएमआई,डायरी,tracker`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  उपयोग की शर्तें: https://doseday.vercel.app/terms
  गोपनीयता नीति: https://doseday.vercel.app/privacy
  ```

## ru — Russia, CIS

- **Name** (24): `Doseday: GLP-1 и пептиды`
- **Subtitle** (26): `Дневник уколов, доз и веса`
- **Keywords** (97): `семаглутид,тирзепатид,glp1,похудение,шприц,ручка,напоминание,побочные,эффекты,имт,трекер,инъекции`
- **End of description** (paste as the last lines of the description; required for subscriptions, Guideline 3.1.2):
  ```
  Условия использования: https://doseday.vercel.app/terms
  Политика конфиденциальности: https://doseday.vercel.app/privacy
  ```
