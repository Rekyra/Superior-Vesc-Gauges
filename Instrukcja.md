2# SuperiorGauges – Instrukcja
Najpierw trzeba wgrać Kalibracja_Napięcia.vescpkg i sprawdzić mnożnik kalibracji dla swojego sterownika.
Następnie wprowadzić tę wartość w punkcie 5 oraz napięcia dla różnych poziomów naładowania w punkcie 6.
Następnie spakować plik QML w Vesc Package i wgrać ponownie na vesc.

---
Najpierw pobieramy plik
Kalibracja_Napięcia.vescpkg w celu sprawdzenia poprawnego mnożnika poprawiającego dokładność wskazania napięcia.

W menu start wybieramy opcję package store.
![kalibracjaNapięcia_krok_1](https://github.com/user-attachments/assets/d0fde1e8-0c2f-43a0-afb4-fbd13b2d167e)
Następnie klikamy w 3 kropki w lewym dolnym rogu
![kalibracjaNapięcia_krok_2](https://github.com/user-attachments/assets/bcc654a1-ca1f-45d3-b971-9a1733dce7ed)
i wybieramy install from file
![kalibracjaNapięcia_krok_3](https://github.com/user-attachments/assets/903464e0-15da-424a-ab41-f79f1d47b434)
następnie wybieramy plik Kalibracja_Napięcia.vescpkg i go wgrywamy.
Po wgraniu pokaże się dodatkowa zakładka w której zobaczymy nowe zegary, a pod nimi można sprawdzić z jakim mnożnikiem na woltomierzu pojawi się poprawne napięcie. (Uwaga vesc przy każdym uruchomieniu będzie wracał do domyślnej wartości mnożnika napięcia i tabelki SOC, dlatego trzeba je nadpisać w pliku qml.)
---

Pobieramy plik SuperiorGaugesV2.qml następnie
uruchamiamy program Vesc tool na komputerze (nie trzeba łączyć się z sterownikiem)
---
Wybieramy opcję QML scripting
<img width="1918" height="1021" alt="krok1" src="https://github.com/user-attachments/assets/ac7dedb5-3edb-465e-a829-1b7a91dba5a0" />
klikamy ikonkę folderu by wybrać plik .qml
<img width="1918" height="1022" alt="krok2" src="https://github.com/user-attachments/assets/414a7f9e-902a-45f0-8ec2-c5ad73ce826e" />
Wybieramy pobrany plik SuperiorGauges.qml
<img width="925" height="662" alt="krok3i4" src="https://github.com/user-attachments/assets/541e47f9-fa80-4aaf-9127-69dea6ce5a1a" />
W punkcie 5 wpisujemy mnożnik napięcia który skoryguje zakłamanie woltomierza.
W punkcie 6 poprawiamy tabelkę na podstawie której obliczany jest stan naładowania, jest ona domyślnie ustawiona dla Sony vtc6  (link do tabelki można znaleźć w ReadMe.md).
Na koniec klikamy dyskietkę w celu nadpisania zmian.
<img width="1918" height="1018" alt="krok5_6_7" src="https://github.com/user-attachments/assets/534c96fa-88d9-4253-a5f8-1c89a9e86f68" />
Wybieramy zakładkę Package Store, następnie Create Package
<img width="1918" height="1020" alt="krok8_9" src="https://github.com/user-attachments/assets/cc0e51fb-0def-470b-a25f-6b023983fe4e" />
W kroku 10 upewniamy się że przy QML kwadracik jest zaznaczony i następnie w kroku 11 wybiewramy wcześniej zmodyfikowany plik QML.
Krok 12 i 13 jest dla osób które podłączają lampkę stop-u do vesc (potrzebny mosfet z optoizolacją) i wtdy należy wgrać skrypt z końcówką .lbm.
<img width="1918" height="1018" alt="krok10_11_12_13" src="https://github.com/user-attachments/assets/01a3d1c8-39ca-4fe8-9c70-9fe297c79bf6" />
Zapisujemy paczkę
<img width="1917" height="1026" alt="krok14" src="https://github.com/user-attachments/assets/e43c94ad-fef1-437c-b0bf-e8b2f3fe50f8" />

---
Na koniec wygrywamy poprawioną paczkę do sterownika.

![kalibracjaNapięcia_krok_1](https://github.com/user-attachments/assets/d0fde1e8-0c2f-43a0-afb4-fbd13b2d167e)
![kalibracjaNapięcia_krok_2](https://github.com/user-attachments/assets/bcc654a1-ca1f-45d3-b971-9a1733dce7ed)
![kalibracjaNapięcia_krok_3](https://github.com/user-attachments/assets/903464e0-15da-424a-ab41-f79f1d47b434)
---
