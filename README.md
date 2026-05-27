2# SuperiorGauges – Zaawansowany ekran wskaźników dla VESC Tool

Zamiennik domyślnego ekranu RT Data w VESC Tool, zaprojektowany dla rowerów elektrycznych, elektrycznych hulajnóg i innych pojazdów opartych na sterownikach VESC. W repozytorium znajdują się również dwa skrypty LispBM do sterowania lampką STOP.
---
<img width="1080" height="2231" alt="IMG_20260527_191641" src="https://github.com/user-attachments/assets/183e1a74-5ffa-4482-b189-17ded2a6c351" />
<img width="1080" height="2228" alt="IMG_20260527_191600" src="https://github.com/user-attachments/assets/ea5ae28a-1d36-463e-87c1-010d0cfed30d" />
---

## Ekran wskaźników – SuperiorGaugesV2.qml

### Nowe Funkcje

- **Zegar prądu baterii** z automatycznym doborem zakresu
- **Obsługa wielu VESC przez CAN** – prąd baterii jest sumą ze wszystkich podłączonych sterowników, co sprawia że skrypt nadaje się do pojazdów dwusilnikowych
- **Mnożnik kalibracji napięcia** – koryguje niedokładność wewnętrznego pomiaru ADC sterownika VESC
- **Własna tabela SOC** – stan naładowania obliczany z definiowanej przez użytkownika krzywej napięciowej ogniwa, niezależnie od wbudowanego algorytmu VESC. Domyślna krzywa: Sony VTC6
- **Woltomierz** pokazujący skalibrowane napięcie pakietu

### Ekran kalibracji (resetuje się przy każdym wyłączeniu sterownika)
Przesuń palcem z dołu do góry na ekranie głównym, aby uzyskać dostęp do:
- Mnożnika kalibracji napięcia
- Edytowalnej tabeli napięć ogniwa

### Tabele napięć ogniw
Aby ułatwić dobór wartości do tabeli SOC dla różnych typów ogniw, przygotowałem tabelę w Google Sheets zawierającą krzywe napięciowe popularnych ogniw litowo-jonowych:

📊 **[Tabela napięć ogniw – Google Sheets](https://docs.google.com/spreadsheets/d/1wsPdnuza7FB2aNU6BxtK0Lr6GHItDyqxO2WwJA4U54E/edit?usp=sharing)**

Na jej podstawie możesz odczytać poziom naładowania odpowiadający danemu napięciu ogniwa i wpisać je bezpośrednio do ekranu kalibracji lub do sekcji `defaultSocVoltages` w pliku QML.

### Konfiguracja domyślna
Edytuj sekcję **`USTAWIENIA DOMYŚLNE`** na początku pliku QML (wiersz 38-48):

```qml
// Mnożnik kalibracji napięcia (1.0 = bez korekcji)
readonly property real defaultVoltageCalibMultiplier: 1.0

// Napięcia ogniwa dla 0%, 5%, 10% ... 100% SOC (domyślnie: Sony VTC6)
readonly property var defaultSocVoltages: [
//   0%     5%     10%    15%    20%    25%    30%
    3.007, 3.183, 3.323, 3.429, 3.494, 3.537, 3.583,
    ...
]
```

### Wymagania
- zainstalowany VESC Tool na Windows, Mac lub Linux
- multimetr lub smartBMS (do sprawdzenia prawidłowego napięcia)
---

## Skrypty lampki STOP – LispBM

Dwa skrypty LispBM do sterowania lampką STOP przez **pin PPM** (skonfigurowany jako wyjście). Hamowanie jest wykrywane gdy **napięcie na pinie ADC2 przekroczy 0,95 V**.

### `Stop_0or1.lbm` – Lampka STOP włącz/wyłącz

Pin PPM jest **domyślnie w stanie niskim** i przechodzi w **stan wysoki tylko podczas hamowania**.

Przeznaczenie:
- Lampki z oddzielnym przewodem do sygnalizacji pozycji i hamowania
- Zestawy z oddzielnymi lampkami pozycji i STOP

| Stan | Pin PPM |
|------|---------|
| Jazda / postój | LOW |
| Hamowanie (ADC2 > 0,95 V) | HIGH |

---

### `Stop_3Hz.lbm` – Migająca lampka STOP (3 Hz)

Pin PPM jest **cały czas w stanie wysokim** i **miga z częstotliwością 3 Hz podczas hamowania**.

Przeznaczenie:
- Dwuprzewodowe lampki używające tych samych diod do sygnalizacji pozycji i hamowania
- Popularne lampki tylne hulajnóg (np. Xiaomi, Kukirin)

| Stan | Pin PPM |
|------|---------|
| Jazda / postój | HIGH (stały) |
| Hamowanie (ADC2 > 0,95 V) | Miganie 3 Hz |

---

## Instalacja
Instrukcja znajduje się w > 📖 [Instrukcja instalacji](Instrukcja.md)

---

## Licencja

GNU General Public License v3.0 – szczegóły w pliku [LICENSE](LICENSE)
