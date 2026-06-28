# **LAPORAN TUGAS BESAR – GAME 3D** **Lumina Defense: The Nightfall Siege  – Tower Defense**

Mata Kuliah: Komputer Grafik – Semester Genap 2025/2026

## **Disusun Oleh:**

Fathin Yassarahman \- 241524041

gambar

# **BAB I – ANALISIS KEBUTUHAN**

## **1.1 Analisis Target Pengguna**

Game Lumina Defense: The Nightfall Siege ditujukan bagi pemain casual hingga midcore di platfom Roblox, khususnya remaja dan dewasa muda (usia 12 hingga 20th) yg menyukai genre strategi.  Permainan ini dirancang agar kompatibel dan intuitif dimainikan, baik menggunakan perangkat PC (dgn mouse dan keyboard) mamupun perangkat mobile (touchscreen)

Analiis targer pengguna dilakukan menggunakan pendekatan brikut:

* Persona pengguna: Pemain yag menyukai tantangan taktis berbasis manajemen sumber daya  
* Benchmark permainan sejenis: mengambil referensi dari Tower Defense Simulator konvensional untuk standar mekanik pertahanan, serta mengadpatasi elemen tekanan waktu lingkungan (day/night cycle) yg sering ditemukan di game survival  
* Referensi edukasi: mengacu pada mekanik dasar dari seri tutorial [*Tower Defense GnomeCode*](https://gnomecode.com/tutorials/tower-defense)  yg dimodifikasi secara ekstensif untuk mengakomodasi sistem deteksi berbasis cahaya/light-based vision dan stealth

## **1.2 Analisis Kebutuhan Perangkat Lunak**

Dalam proses pengembangan Lumina Defense, perangkat lunak yg digunakan mencakup tools standar industri dan program tambahan untuk memenuhi spesifikasi tugas:

* Roblox studio: Sebagai game engine utama untuk perakitan level, manipulasi Lighting (ClockTime), dan playtesting  
* Visual Studio Code & Rojo: digunakan sebagai environment pemrograman eksternal untuk live coding bahasa Luau agar lebih terstruktur dan efisen  
* Blender: Digunakan untuk modelling 3D aset statis  
* Github: Digunakan sbg versioning control untuk pencadangan proyek (URL: [https://github.com/ckluk416/lumina-defense](https://github.com/ckluk416/lumina-defense))

## **1.3 Analisis Kebutuhan Perangkat Keras**

Untuk mendukung pengembangan yg melibatkan simulasi dynamic lighting (perubahan pencahayaan siang-malam secara terus menerus) dan rendering material PBR, diperlukan perangkat keras dengan sepsifikasi sbg berikut”

* Spesifikasi minimum:  
- CPU: intel core i3 / AMD ryzen 3  
- RAM: 8GB  
- GPU: IGPU (intel UHD graphics/AMD radeon vega)  
* Spesifikasi rekomendasi (untuk development):  
- CPU: Intel Core i5/AMD ryzen 5 atau lebih tinggi  
- RAM: 16GB  
- GPU: DGPU untuk memproses kalukasi bayangan (shadow mapping) dan rendering part secara mulsu tanpa lag di Roblox Studio

# 

# **BAB II – RANCANGAN APLIKASI**

## **2.1 Core Experience**

Lumina Defense: The Nightfall SIege memberikan pengalaman strategis yang mendalam dimana pemain harus menempatkan menara/tower pertahanan, melawan gelombang/wave musuh yang semakin sulit, melakukan upgrade, dan mengelola ekonomi. Core experience yg membedakan game ini terletak pada kemampuan adaptasi pemain terhadap sikuls waktu (siang-malam). Pemain dituntut untuk tidak hanya memikirkan daya serang tower, tetapi juga mengelola penempatan light node secara taktis untuk mengekspos musuh yang memiliki kemampuan tak kasat mata (stealth) di malam hari.

## **2.2 Core Direction**

Alur permainan (flow) secara garis besar dari awal pemain masuk hingga permaina berakhir (menang atau kalah) dijelaskan melalui diagram berikut:

Ketrangan diagram alur game:

1. Spawn di lobi: pemain masuk ke dalma permainan dan muncul di are lobby, sebuah platformmelingakr dgn papan cara bermain, papan lederboard, dan portal masuk ke arena  
2. Masuk ke map: pemain mendekati portal dan menyentuhnya untuk tleport ke area permainan. Semua state (uang,wave, hp markas, jumlah tower) langsung disingkronkan ke pemain  
3. Fase intermission (persiapan): pemain diberikan modal awal sebesar $500 untuk mulai menempatkan tower dan light node di area yg diizinkan. Rute musuh ditampilkan dgn garis neon sbg panduan  
4. Fase gelombang (siang-malam)” musuh mulai spawn dari portal dan berjalan mengikuti rute menuju markas. Siklus waktu berjalanm setiap wave ke-3 (kelipatan) adalah malam, dimana musuh stealth muncul dari tower tidak bisa menembak tanpa cahaya light node  
5. Kondisi hp markas: sistem terus mengecek nyawa (health) markas. Jika HP habis, pemain dinaytakan kalah (game over)  
6. Infinite wave: tidak ada kondisi menang, gelombang terus berlanjut (scaling procedural) hingga markas hancur. Semakin lama bertahan, semakin tinggi skor leaderboard

## **2.3 Keywords**

Kata Kunci yang merepresentasikan mekanik dan indetitas dari permainan ini adalah:

* Pathing & waypoints (jalur musuh)  
* Tower placement & upgrade (penempatan dan peningkatan menara)  
* Wave management (manajemen gelombang musuh)  
* Resouce Economy (ekonomi ingame)  
* Day/night cycle (siklus siang-malam dinamis)  
* Light-based Vision (deteksi radius berbasis chaaya)  
* Stealth enemies (musuh tak kasat mata)  
* Procedural map generatoin (peta yg dihasilkan secara acak setiap permainan)

## **2.4 Design Principles**

Dalam merancang Lumina Defense, diterapkan empat prinsip desian utama untuk memasatikan pengalaman bermain yg berkualitas:

1. Clarity(kejelasan): visual dan antarmuka harus mudah dipahami. Pemain dapat melihat dengan jelas radius serangan tower dan radius pencahayaan dari light node. Perubahan waktu dari siang ke malam hari juga ditandai dengan perubahan pencahayaan (lighting) lingkungan dan notifikasi UI yg jelas  
2. Meaningful choice (pilihan bermakna): pemain dihadapakna pada dilema ekonomi yg taktis. Pemain haru memilih apakah uang (resource) yg terbatas akan digunakan untuk memperkuat damage tower di siang hari, atau membeli light node tambahan sebagai persiapan menghadapi malam hari.  
3. Fair Challange (tantangan yg adil): kesulitan tidak ditingkatkan secara sewenang-wenang. Tantnagna di malam hari akan meingkat karena kerebatasan jarak pandang, bukan murni karena kekuatan musuh, sehingga pemain yg melakukan persiapan cahaya yg baik tetap dapat bertahan  
4. Feedback (umpan balik): sistem memberikan respons visual atas tindakan pemain. Contohnya: efek proyektil saat tower menyerang, notifikasi UI setiap kali wave baru dimulai, serta perubahan warna HP bar saat terkena damage

## **2.5 Core Loop**

Core loop adalah aktivitas berulang yang dilakukan oleh pemain selama berada di dalam permainan untuk mencapai tujuan akhir (kemenangan).

Siklus dimulai saat wave baru berjalan dan musuh bermunculan. Tower yang telah ditempatkan pemain akan menyerang musuh secara otomatis. Setiap musuh yang dikalahkan akan memberikan uang (reward) kepada pemain. Uang tersebut kemudian diputar kembali oleh pemain ke dalam siklus ekonomi permainan untuk membeli Tower baru, meningkatkan (upgrade) Tower yang ada, menambah slot tower, atau membeli Light Node sebagai persiapan menghadapi malam hari. Siklus ini terus berulang hingga nyawa markas habis.

## **2.6 Core Mechanics**

Mekanik inti pemainan dibangun berdasarkan fondasi tower defense konvensional yg dimodifikasi dengan elemen manipulasi lingkungan (environment). Berikut adalah rinciannya:

1. Path navigation: sistem perbegerakan musuh yg dikendalikan oleh EnemyAI untuk berjalan secara berurutan mlewati titik titik kordinat/waypoints dari tempat spawn menuju markas utama  
2. Waves system (day/night dependant): sistem pengatur gelombang musuh yg terintegrasi dengan siklus siang-malam. Malam terjadi setiap wave ke-3 (waveNumber % 3 \== 0), dipicu oleh waveManager dan LightingController yg mentransisikan properti lighting scr smooth. Pada malam hari, musuh tipe StealthEnemy ikut muncul dalam komposisi wave  
3. Enemy types: terdapat dua tipe musuh:  
- BasicEnemy; musuh standar dng HP 100, damage 10, speed 12, rewards $15 (bertambah seiring wave). Muncul di semua wave.  
- StealthEnemy: musuh bayangan dgn HP 60, dmg 10, speed 16, rewards $25. Hanya muncul di wave malam (wave-3 dan kelipatannya) dan tidak “terlihat”/tidak bisa ditembak jika tidak berada dalam radius cahaya light node  
4. Tower shooting & light-vision: CombatManager menggunakan kalkulasi jarak matematic (magnitude) untuk mendeteksi musuh terdekat disteiap heartbeat. Saat malam hari, tower tidak bisa menembak musuh Stealth kecuali musuh tersebut berada di dalam radius penchaaan light node  
5. Tower tipe & upgrade: tedapt 4 tipe tower yg bisa dibangun:  
- ArcherTower ($50): serangan fisik cepat, projektil lurus  
- MageTower ($80): serangan sihir area (AOE), projectil orb  
- Mortar ($220): artileri jarak jauh dengn ledakan area, projektil parabola  
- LightNode ($30): tidak menyerang, memancarkan cahaya untuk mendeteksi Stealth  
- Setiap tower bisa di upgrade 3 level dgn skala: damage x1.3, range x1.12, fire rate x0.92 per level  
6. GUI, money & slot: sistem antarmuka yg mengelola penempatan tower, penambahan uang secara realtime saat musuh terbunuh, dan menu interktif untuk upgrade. Setiap pemain memiliki 12 slot tower secara default. Bisa ditambha dgn membeli extra slot ($300, harga meningkat x1.6 setiap pembelian)  
7. Camera system: pemain dapat menekan V untuk beraleh ke kamera top-down RTS (tactical) yg melihat kebawah, memudahkan penempatan tower. Kamera bisa di-pan dengan WASD dan di zoom dgn scroll mouse. Pemain dapat menghapus tower yang sudah ditempatkan dengan mengaktifkan Mode Hapus lalu mengklik tower. Sistem akan mengembalikan 50% dari harga dasar tower sebagai refund.

## **2.7 Gameplay Mechanic**

Diagram disamping mengilustrasikan logic skrip pertahanan yg terus berjalan (menggunakan RunService.heartbeat). CombatManager loop, jika tower mendetkeis musuh di areanya, sistem akan mengecek status siang/malam. Jika siang, tower langsung menembhak dgn projektil yg seusai (arrow untuk ArhcerTower, orb untuk MageTower, shell parabola untuk Mortar). Jika malam, sistem akan mengecek apakah posisi musuh stealth berada dalam radius light nodeterdekat menggunakan fungsi isEnemyRevealed() dari TowerAttack (shared module). 

## **2.8 Screenflow**

![][image1]

Pemain langsung spawn di ara lobi. Dari situ, pemain masuk melalui portal ke dalam game HUD dimana permainan berlangsung. Di dalam HUD ini, pemain dapat menempatkan tower, melakukan upgrade, dan memberi extra slot. Saat permainan berakhir (game over)

## **2.9 Storyboard**

Antarmyka visual permainan (uiux) dirancang menggunakan estetika modern berbasis bento grid dan glassmorphism agar tidak menutupi visibilitas map 3D di belakangnya

1. Storyboard lobby: area lobby berbentuk platform silinder dgn papan “CARA BERMAIN” di kiri dan papan “LEADERBOARD” di kanan. Di depan terdapat portal dengan label “MASUK GAME”. Pemain spawn langsung di platofrom ini  
2. Storyboard arena /game HUD: tedapat indikator siang/malam dan nomor wave, stats HP markas, jumlah uang pemain, statisitik kill dan sisa musuh dalam wave tsb., hotbar untuk memilih tower serta tombol mode hapus dan upgrade, serta menambhakan slot tower. Pemain dapat menekan V untuk beralih ke kamera top-down RTS yg melihat lurus ke bawah, memudahkan penempatan tower secara presisi  
3. Storyboard Upgrade Panel: Saat pemain menghover tower yang sudah diletakkan di map, akan muncul sebuah panel pop-up melayang di Tower tersebut. panel menampilkan perbandingan statistik damage, range, fire rate level saat ini vs level berikutnya, serta lingkaran indikator range sebelum dan sesudah upgrade. Tombol "Upgrade" dilengkapi dengan harga yang harus dibayar  
4. Storyboard Shop: panel shop berupa hotbar yg selalu terlihat di bagian bawah layar.  Setiap item menampilkan nama, ikon, dan harga. Pemain mengklik item untuk mengaktifkan mode placement, model tower transparanakan mengikuti kursor dengan grid snapping 4-stud, dan lingkaran range akan muncul. Klik kiri untuk mengonfirmasi penempatan, klik kanan atau Esc untuk membatalkan.

# 

# **BAB III – PEMBUATAN ASET**

## **3.1 Asset Script**

Logika utama dari permainan Lumina Defense: The Nightfall Siege digerakkan oleh skrip Luau yang berjalan di sisi server dan client. Berikut adalah deskripsi dari skrip utama yang mengatur berjalannya mekanik inti permainan:

1. MapGenerator.luau (server): skrip yang membangun tata letak map secara prosedural setiap kali permainan dimulai. Menghasilkan 2-4 route acak dari portal menuju Base, lengkap dengan waypoints, footpath batu, dekorasi alami (pohon, batu), dan tiga lapis dinding gunung melingkar. Map lama dibersihkan otomatis sebelum generat baru. dkkorasi dikerjakan secara async (task.spawn) agar tidak menghambat startup  
2. EnvironmentSetup.luau (server): skrip konfigurasi yang membaca hasil generate MapGenerator dari Workspace (SpawnPoint, Route folder, waypoints) dan mengeksposnya ke sistem lain seperti WaveManager dan EnemyAI. Bertindak sbg jembatan antara output MapGenerator dan gameplay  
3. EnemyAI.luau (server): mengelola seluruh siklus hidup musuh spt spawning, konversi rig (WeldConstraint ke Motor6D untuk animasi), pergerakan berbasis waypoints menggunakan Humanoid:MoveTo(), penanganan damage/kematian dengan efek death (tween jatuh \+ fade-out), serta distribusi reward uang saat musuh terbunuh. mengekspos EnemyRemoved BindableEvent yang dikonsumsi oleh WaveManager  
4. CombatManager.luau (server): menjalankan heartbeat combat setiap frame. mendaftarkan tower yang ditempatkan dengan statistiknya dari TowerAttack (shared module), memindai target musuh setiap frame menggunakan pengecekan jarak/range dengan mempertimbangkan status stealth dan reveal oleh light node, serta menembakkan efek proyektil (arrow untuk ArcherTower, orb untuk MageTower, cannon shell untuk CannonTower, missile parabola untuk Mortar) dengan interpolasi lintasan linear maupun kuadratik. Mendukung splash damage AOE untuk MageTower dan Mortar, serta upgrade scaling (damage x1.3, range x1.12, fire rate x0.92 per level)  
5. TowerAttack.luau (shared): sumber data terpusat untuk statistik dasar tower, formula upgrade, biaya, dan utilitas pengecekan range. Digunakan oleh client (untuk preview penempatan dan tooltip upgrade) maupun server (inisialisasi statistik di CombatManager)  
6. WaveManager.luau (server): skrip sentral yang mengatur siklus permainan, waktu jeda antar gelombang (intermission), memunculkan (spawn) musuh dari setiap route, dan mengatur tingkat kesulitan. terintegrasi dengan LightingController untuk transisi siang-malam: setiap wave ke-3 (waveNumber % 3 \== 0\) adalah malam, memicu spawn StealthEnemy. Wave setelah wave ke-7 menggunakan scaling procedural (jumlah musuh, speed, spawn delay) tanpa batas atas  
7. LightingController.luau (server): mengelola sistem pencahayaan siang/malam dengan transisi smooth. Mendefinisikan profil Day dan Night (ClockTime, Ambient, OutdoorAmbient, Brightness, FogColor). Transisi menginterpolasi semua properti lighting secara bertahap dan mengirimkan event UpdateDayNight ke client setelah selesai  
8. EconomyManager.luau (server): manajemen uang pemain. Setiap pemain mendapat modal awal $500 saat join. Menangani penambahan (add), pengurangan (deduct), dan pengecekan saldo. Dilindungi dengan idempotent guard untuk mencegah overwrite wallet  
9. PlacementHandler.luau (server): menangani permintaan penempatan, penghapusan, upgrade tower, dan pembelian slot dari client. Melakukan validasi: biaya (melalui EconomyManager), jarak minimal antar tower (14 studs), batas slot per pemain (12 default \+ extra slot), kepemilikan tower untuk upgrade/remove. Memberikan refund 50% saat tower dihapus  
10. PlacementSystem.luau (client): mengelola pengalaman interaktif penempatan tower , preview transparan yang mengikuti kursor, grid snapping 4-stud, indikator lingkaran range dan inner range, highlight merah pada mode hapus, serta tooltip upgrade dengan perbandingan statistik dan perbandingan lingkaran range. Mendukung shortcut keyboard B (ArcherTower), N (LightNode), M (MageTower), L (Mortar).  
11. UIController.luau (client): membangun seluruh HUD ScreenGui. indikator wave, progress bar HP markas, tampilan uang, indikator siang/malam, pesan status, jumlah tower, statistik kill, tombol shop untuk 4 tipe tower, tombol mode hapus/upgrade, tombol beli slot, tombol mulai wave, dan tombol kembali ke lobby. Mendengarkan semua RemoteEvent dari server untuk memperbarui UI secara realtime.  
12. CameraController.luau (client): menyediakan kamera top-down RTS taktikal. Pemain menekan V untuk beralih antara kamera normal dan kamera top-down yang melihat lurus ke bawah. Dalam mode ini, kamera dapat di-pan dengan WASD dan di-zoom dengan scroll mouse (rentang 50-250 studs). Karakter pemain berhenti bergerak saat mode taktikal aktif.  
13. LobbyBuilder.luau (server): membangun area lobby. platform silinder, papan cara bermain, papan leaderboard, dekorasi batu minimalis, dan portal dengan trigger Touched untuk teleport pemain ke map. Saat pemain masuk portal, semua state game (uang, wave, HP, tower count) disinkronkan ke client yang baru masuk.  
14. PathPreview.luau (server): menggambar garis neon berwarna di antara waypoints setiap route untuk menunjukkan jalur musuh kepada pemain sebelum wave dimulai. Mendukung clear preview dan fade-out smooth.  
15. VisualEffects.luau (server): menangani animasi kosmetik. rotasi orbital ring pada model Base (3 ring pada sumbu berbeda) dan LightNode (3 energy ring), serta scaling visual upgrade LightNode (ukuran ring, range PointLight, brightness, transparansi core).  
16. EnemyAnimator.luau (client): menyediakan animasi jalan procedural client-side untuk model musuh. Menggunakan sinusoidal contralateral gait (lengan berlawanan dengan kaki) yang dikomputasi dari perpindahan posisi realtime musuh. Berjalan lokal di setiap client karena Motor6D.Transform tidak reliabel untuk direplikasi dari server  
17. LeaderboardService.luau (server): melacak wave terbaik setiap pemain menggunakan OrderedDataStore. Pada saat game over, reportWave() menulis nomor wave pemain jika melebihi catatan sebelumnya. getTop() mengambil daftar leaderboard terurut dari tertinggi

## **3.2 Asset 3D**

Kebutuhan visual dari Lumina Defense mencakup beberapa kategori model 3D yang dibuat melalui script Python di Blender (untuk aset statis) maupun pemodelan manual (untuk karakter). Sesuai dengan spesifikasi tugas, aset statis untuk kebutuhan dekorasi environment dan properti permainan di-generate secara prosedural menggunakan skrip Python di Blender, sementara karakter musuh dimodelkan manual

| No | Asset | Code | Pembuat |
| :---- | :---- | :---- | :---- |
| 1 | ArcherTower\_Roblox | https://github.com/ckluk416/lumina-defense/blob/main/asset-script/archer-tower.py | Fathin (241524041) |
| 2 | MageTower\_Roblox | https://github.com/ckluk416/lumina-defense/blob/main/asset-script/mage-tower.py | Fathin (241524041) |
| 3\.  | Mortar\_Roblox | https://github.com/ckluk416/lumina-defense/blob/main/asset-script/mortar-tower/mortar-v2.py | Fathin (241524041) |
| 4 | LightNode\_Roblox | https://github.com/ckluk416/lumina-defense/blob/main/asset-script/light-node.py | Fathin (241524041) |
| 5 | Base\_Roblox | https://github.com/ckluk416/lumina-defense/blob/main/asset-script/base.py | fathin |
| 6 | SpawnPortal\_Roblox | https://github.com/ckluk416/lumina-defense/blob/main/asset-script/portal/portal-v1.py | fathin |
| 7 | CannonTower\_Roblox (sayang dibuang) | https://github.com/ckluk416/lumina-defense/blob/818d40aed1fb34511236a381d45e8b1855b4f833/asset-script/cannon-tower/cannon-tower-v2.py | Fathin  |

Keterangan model:

1. ArcherTower\_Roblox: Menara pemanah otomatis dengan serangan fisik cepat. Terdiri dari Base (tiang penyangga kayu dengan besi) dan Turret (platform bundar dengan ballista mekanis). Material custom di roblox. Proyektil: anak panah lintasan lurus.  
2.  MageTower\_Roblox: Menara sihir kuno dengan serangan area (AOE). Terdiri dari Base (pilar batu dengan ukiran rune) dan Turret (kristal prisma melayang). Warna custom rolbox. Proyektil: orb energi yang meledak saat mengenai musuh.  
3.  Mortar\_Roblox: Artileri berat jarak jauh dengan serangan lambat berdaya ledak tinggi (AOE). Landasan baja melingkar dengan laras berdiameter besar mendongak ke atas. Warna custom roblox. Proyektil: missile parabola dengan splash damage.  
4.  LightNode\_Roblox: Struktur kristal penerang yang memancarkan cahaya untuk mendeteksi musuh stealth di malam hari. Penyangga logam tiga kaki dengan bola kristal di bagian atas yang memancarkan emisi kuning hangat.  
5.  Base\_Roblox: Markas utama yang harus dijaga. Terdiri dari Core (kristal melayang biru neon), tiga tiang generator melingkar, dan landasan logam bundar dengan cincin energi. Dilengkapi orbital ring yang berputar secara animatif.  
6.  SpawnPortal\_Roblox: Portal tempat musuh muncul. Gerbang batu kuno retak dengan kabel futuristik melilit pilar, pusaran vortex ungu di tengah yang berputar.  
7.  BasicEnemy: Musuh standar humanoid. Warna hitam arang \+ aksen hijau neon. Tinggi 6 studs, dibuat dalam T-Pose untuk kompatibilitas animasi.  
8.  StealthEnemy: Musuh bayangan, mata celah vertikal menyala merah.  CannonTower\_Roblox: Menara meriam alternatif dengan damage tinggi dan fire rate sedang, sebagai varian tambahan dalam gameplay.

# 

# **BAB IV – PEMBUATAN LINGKUNGAN SIMULASI**

Tadinya map map awal dibuat secara manual, tapi setelah mendpat kabar bahwa perlunya generete via skrip, maka dibuat skrip untuk menggneerate

## **4.1 Procedural Map Generation**

Lingkungan permainan tidak dibuat manual di Roblox Studio, melainkan di-generate secara prosedural setiap kali permainan dimulai oleh skrip MapGenerator.luau. Proses generasi berlangsung dalam urutan berikut:

1. Pembersihan map lama: semua objek hasil generte sebelumnya (SpawnPoint, Route, Portal, MapDecoration, MapBoundary, MapFootpaths) dihapus dari Workspace untuk mencegah penumpukan antar playtest.  
2. Pembangunan dinding gunung (Mountain Wall Ring): tiga lapis dinding gunung melingkar dengan radius 205, 222, dan 242 studs dibangun menggunakan part-part segmen (mountainSeg). Tinggi setiap segmen bervariasi menggunakan gelombang sinus \+ jitter acak (heightMin 20-45, heightMax 35-70 tergantung ring). Segmen dengan puncak tertinggi mendapat snow cap (bola salju) di atasnya. Total \~300-400 segmen membentuk formasi gunung yang mengelilingi area bermain.  
3. Penentuan route: jumlah route ditentukan secara acak berbobot (2 route 35%, 3 route 40%, 4 route 25%). Setiap route diposisikan pada sudut yang tersebar merata di sekitar Base dengan jitter acak. Jarak portal dari Base bervariasi antara 90-160 studs.  
4. Pembangunan waypoints: setiap route memiliki 4-6 waypoints yang dihasilkan dengan algoritma winding . titik tengah route digeser secara acak tegak lurus arah route dengan kekuatan PATH\_BEND\_STRENGTH (24 studs) dan taper sinusoidal untuk memberi efek berkelok alami. Beberapa route (35% chance) mendapat detour khusus yang membuatnya tampak lebih panjang dan bersilangan visual dengan route lain.  
5. Pembangunan footpath: setiap route dilapisi jalan slab selebar 7 studs di sepanjang waypoints. Setiap segmen jalan dibuat dari part Slate dengan sambungan melingkar (joint) di tiap titik waypoint untuk menutup celah antar segmen.  
6. Penempatan portal: model SpawnPortal\_Roblox di-clone dan ditempatkan di ujung awal setiap route menggunakan metode TranslateBy, dengan snapping ke permukaan tanah (GROUND\_LEVEL \= 2).  
7. Dekorasi lingkungan: pohon, batu, dan elemen dekorasi ditempatkan di sepanjang route dan di area luar antara route dan dinding gunung. Proses ini berjalan secara async (task.spawn) agar tidak memperlambat startup. Detail dekorasi dijelaskan pada sub-bab 4.2.

## **4.2 Sistem Dekorasi Prosedural**

Dekorasi lingkungan menggunakan model dari Creator Store yang di-clone dan ditempatkan secara prosedural dengan aturan berikut:

- Exclusion zones: area dalam radius 28 studs dari Base dan 22 studs dari setiap portal dibiarkan kosong untuk menjaga visibilitas area combat. Dekorasi juga tidak boleh berada dalam jarak 14 studs dari centerline path.  
- Spacing: minimal 8 studs antar item dekorasi untuk mencegah tumpang tindih.  
- Density gradient: semakin jauh dari Base, semakin banyak dan semakin besar item dekorasi. Area dekat Base (dist \< 60\) didominasi batu kecil, area tengah campuran pohon dan batu, area dekat dinding gunung (dist \> 130\) menjadi hutan lebat dengan pohon berukuran besar.  
- Clustering: di area luar, item-item dekorasi dikelompokkan secara alami. setelah menempatkan item utama, ada kemungkinan 30-60% untuk menempatkan 1-2 item tambahan dalam radius 8-14 studs.  
-  Scale gradient: ukuran item bertambah seiring jarak dari Base. 0.5× di dekat Base hingga 1.2× di dekat dinding gunung.

## **4.3 Lingkungan Lobby**

Area lobby dibangun oleh LobbyBuilder.luau di koordinat terpisah (Y=600) dari arena permainan agar tidak bertabrakan:

- Platform: silinder dengan radius 32 studs, warna abu-abu terang dengan ring aksen biru neon.  
- Spawn point: spawn location default pemain saat masuk game. Spawn location lama di area map dinonaktifkan.  
- Papan informasi: SurfaceGui pada part board yang menampilkan cara bermain dalam bahasa Indonesia serta leaderboard yang di-refresh setiap 30 detik menggunakan LeaderboardService.  
- Portal: model SpawnPortal\_Roblox yang telah dimodifikasi sebagai pintu masuk ke arena game. Dilengkapi trigger Touched yang mendeteksi pemain, menyingkronkan state game (uang, wave, HP, jumlah tower), dan memindahkan pemain ke koordinat spawn arena (8, 5, 12).  
-  Dekorasi: beberapa batu minimalis di sekeliling platform sebagai aksen.

## **4.4 Setup Environment**

Setelah map di-generate, EnvironmentSetup.luau memvalidasi keberadaan semua objek yang diperlukan:

- Setiap route harus memiliki SpawnPoint\_\<id\> (Part transparan sebagai referensi spawn musuh)  
- Setiap route harus memiliki Route\_\<id\>/ folder berisi waypoint parts (bernama 1, 2, 3, ...)  
- Base model harus ada di Workspace

EnvironmentSetup mengekspos fungsi getSpawnPosition(routeId) dan getRouteWaypoints(routeId) yang digunakan oleh WaveManager untuk spawning musuh dan oleh EnemyAI untuk navigasi.

# 

# **BAB V – PENGATURAN CONTROLLER**

## **5.1 Mouse Raycast untuk Penempatan Tower**

Penempatan tower menggunakan sistem raycast dari mouse. Saat pemain mengaktifkan mode placement (dengan mengklik tombol tower di hotbar atau menekan shortcut keyboard), PlacementSystem.luau di sisi client akan:

1. Menembak ray dari kamera ke arah mouse menggunakan UserInputService:GetMouseLocation() dan Workspace:Raycast().  
2. Mendeteksi permukaan tanah (baseplate/terrain) sebagai target penempatan.  
3. Menampilkan model ghost transparan yang mengikuti kursor dengan grid snapping 4-stud.  
4. Menampilkan lingkaran radius serangan tower dan inner range ( jika ada).  
5. Mengonfirmasi penempatan dengan klik kiri (LMB) dan membatalkan dengan klik kanan (RMB) atau tombol Esc.

Sistem ini memungkinkan pemain melihat dengan tepat dimana tower akan ditempatkan sebelum mengonfirmasi, termasuk visualisasi range tower terhadap jalur musuh yang sudah dipreview.

## **5.2 Kamera Top-Down RTS (Taktikal)**

CameraController.luau di sisi client menyediakan mode kamera alternatif yang dapat diaktifkan dengan menekan tombol V:

- Mode Normal: kamera third-person standar Roblox mengikuti karakter pemain di area lobby.  
- Mode Taktikal (V): kamera beralih ke mode Scriptable, melihat lurus ke bawah dari atas (top-down view). Rentang ketinggian 50-250 studs. Cocok untuk menempatkan tower secara presisi dan memantau pergerakan musuh di seluruh map.  
- Panning: pemain dapat menggeser kamera menggunakan tombol WASD atau arrow keys. Pergerakan halus dan mengikuti arah input.  
- Zoom: scroll mouse untuk memperbesar/memperkecil pandangan, dibatasi antara 50 studs (dekat) hingga 250 studs (jauh, mencakup hampir seluruh map).  
- Toggle: tekan V lagi untuk kembali ke mode kamera normal. Saat mode taktikal aktif, karakter pemain berhenti bergerak.

## **5.3 Shortcut Keyboard**

Permainan menyediakan shortcut keyboard untuk mempercepat interaksi pemain:

| Tombol | Fungsi |
| :---- | :---- |
| B | Aktifkan mode placement ArcherTower |
| N | Aktifkan mode placement LightNode |
| M | Aktifkan mode placement MageTower |
| L | Aktifkan mode placement Mortar |
| V | Toggle kamera top-down RTS |
| RMB / Esc | Batalkan mode placement saat ini |
| LMB | B	Konfirmasi penempatan tower / pilih tower untuk upgrade |

## **5.4 Mobile Touch Support (Future Implementation)**

Meskipun saat ini pengembangan difokuskan untuk perangkat PC (mouse dan keyboard), struktur kode menggunakan UserInputService yang secara native mendukung touch input di Roblox. Tombol hotbar yang ada di bagian bawah layar sudah dapat berfungsi dengan sentuhan langsung untuk memilih tower yang akan ditempatkan. Pengembangan lebih lanjut untuk kontrol mobile (joystick virtual, gesture zoom) dapat ditambahkan pada iterasi berikutnya.

# **BAB VI – PEMBUATAN HALAMAN MENU**

Pada Lumina Defense: The Nightfall Siege, tidak terdapat halaman menu utama (main menu) tradisional. Pemain langsung masuk ke area lobby yang berfungsi sebagai hub sentral, menggantikan peran main menu, map selection, dan loading screen.

## **6.1 Lobby System**

Area lobby dibangun oleh LobbyBuilder.luau di koordinat (X=0, Y=0.5, Z=600) — terpisah dari arena permainan agar tidak bertabrakan visual. Komponen lobby meliputi:

1.  Lobby Platform: sebuah silinder dengan radius 32 studs, warna abu-abu terang (RGB 235, 235, 240), dilengkapi ring aksen biru neon tipis di sekelilingnya. Platform ini menjadi tempat pemain muncul saat pertama kali masuk game atau setelah kembali dari permainan.  
2.  Spawn Point: SpawnLocation yang ditempatkan di atas platform, menjadi titik muncul default pemain. Spawn location lama yang berada di area permainan dinonaktifkan.  
3.  How-to-Play Sign: papan informasi di sisi kiri platform yang menampilkan petunjuk cara bermain dalam bahasa Indonesia:  
-  Cara menempatkan tower (klik tombol toko atau shortcut B/N/L/M)  
- Cara menghapus tower (mode hapus)  
- Informasi siklus siang-malam dan musuh stealth  
- Informasi slot tower terbatas dan pembelian slot tambahan  
4.  Leaderboard Sign: papan informasi di sisi kanan platform yang menampilkan 5 pemain teratas berdasarkan wave tertinggi. Data diambil dari LeaderboardService (OrderedDataStore) dan di-refresh secara otomatis setiap 30 detik.  
5. Dekorasi Lobby: beberapa batu minimalis ditempatkan di sudut-sudut platform sebagai aksen visual.

## **6.2 Portal Mechanism**

Portal yang terletak di sisi depan platform berfungsi sebagai tombol "Play" untuk memulai permainan. Mekanismenya:

1. Pemain mendekati portal dan menyentuh area trigger (invisible part berukuran 10x8x4 studs di depan portal).  
2. Sistem mengecek debounce untuk mencegah multiple trigger.  
3. Pemain di-teleport ke koordinat spawn arena (X=8, Y=5, Z=12).  
4. Seluruh state game (uang, wave berjalan, HP markas, statistik wave, jumlah tower) disinkronkan ke client pemain yang baru masuk — penting karena pemain melewatkan semua event FireAllClients selama berada di lobby.  
5. Client menerima event UpdateMapState(true) untuk mengaktifkan HUD permainan.  
6. Setelah teleport, debounce aktif selama 2 detik.

## **6.3 Return-to-Lobby**

Setelah game over (HP markas mencapai 0), pemain dapat kembali ke lobby melalui mekanisme berikut:

1. Client mengirim RequestReturnToLobby ke server.  
2. Server memindahkan karakter pemain kembali ke koordinat lobby (X=0, Y=4.5, Z=618).  
3. Client menerima event UpdateMapState(false) untuk menonaktifkan HUD permainan dan menampilkan kembali lingkungan lobby.

# **BAB VII – HALAMAN PERMAINAN**

7.1 Layout HUD

Antarmuka permainan dibangun oleh UIController.luau sebagai ScreenGui dengan tata letak sebagai berikut:

- Bagian kiri atas: indikator siang/malam (label "SIANG"/"MALAM") dan label nomor wave. Dan hari  
- Tengah atas: progress bar HP markas dengan warna hijau → kuning → merah seiring berkurangnya HP,  
- Kanan atas: jumlah uang pemain (dalam format $XXX).  
- Dibawah bagian atas: statistik pertempuran. jumlah kill basic enemy, kill stealth enemy, sisa musuh dalam wave saat ini, dan total musuh dalam wave.  
- Bagian bawah tengah: hotbar berisi 4 tombol tower (ArcherTower $50, LightNode $30, MageTower $80, Mortar $220), tombol mode hapus, tombol mode upgrade, dan tombol beli slot tower.  
- Dibawah Pojok kiri atas: jumlah tower terpasang (dengan peringatan warna kuning/merah jika mendekati batas).

## **7.2 Shop System (Hotbar)**

Shop tidak berupa panel pop-up yang muncul dari samping, melainkan hotbar yang selalu terlihat di bagian bawah layar ketika masuk intermission. Setiap tombol menampilkan:

- Nama tower  
- Harga dalam $

Saat pemain mengklik tombol tower, mode placement aktif (lihat 7.3). Mode placement hanya dapat digunakan saat wave tidak aktif (status "Intermission"). Jika wave sedang berjalan, tombol shop dinonaktifkan untuk menjaga fair play.

## **7.3 Mode Placement**

Saat pemain memilih tower dari hotbar, PlacementSystem.luau mengaktifkan mode placement:

1. Model ghost transparan tower mengikuti posisi kursor di atas map.  
2. Posisi ghost mengunci ke grid 4-stud untuk penempatan presisi.  
3. Lingkaran radius serangan tower (dan inner range jika ada) ditampilkan di sekitar ghost.  
4. Jika tower terlalu dekat dengan tower lain (jarak \< 14 studs), ghost berubah menjadi merah sebagai indikasi lokasi tidak valid.  
5. Klik kiri (LMB) untuk mengonfirmasi penempatan — server memvalidasi biaya, slot, dan jarak.  
6. Klik kanan (RMB) atau Esc untuk membatalkan mode placement.

## **7.4 Mode Hapus**

Pemain dapat mengaktifkan Mode Hapus dari tombol di atas kiri:

1. tower milik pemain diberi highlight merah saat di hover.  
2. Saat pemain mengeklik tower yang di-highlight, server memproses penghapusan.  
3. Server mengembalikan 50% harga dasar tower sebagai refund ke pemain.  
4. Jumlah tower terpakai berkurang.

## **7.5 Mode Upgrade**

Pemain mengaktifkan Mode Upgrade dari tombol atas kiri, lalu mengeklik tower yang ingin ditingkatkan:

1. Tower yang dapat di-upgrade diberi highlight emas.  
2. Panel tooltip melayang muncul di samping tower, menampilkan:  
- Damage saat ini → damage setelah upgrade  
- Range saat ini → range setelah upgrade (dengan lingkaran perbandingan)  
- Fire rate saat ini → fire rate setelah upgrade  
- Biaya upgrade  
3. Jika tower sudah mencapai level maksimal (level 3), panel menampilkan "MAX" dan tidak ada tombol upgrade.  
4. Pemain mengonfirmasi upgrade melalui panel.

## **7.6 Wave Start Button**

Saat dalam mode intermission (antar wave), sebuah tombol "MULAI WAVE N\!" muncul. Tombol ini:

- Menampilkan nomor wave berikutnya  
- Jika wave berikutnya adalah malam (wave kelipatan 3), menampilkan peringatan "MALAM — Musuh Stealth\!"

## **7.7 Extra Slot Purchase**

Pemain dapat membeli slot tower tambahan melalui tombol di hotbar:

- Harga dasar: $300  
- Harga meningkat dengan faktor 1.6× setiap pembelian ($300 → $480 → $768 → ...)  
- Jumlah slot maksimum bertambah 1 per pembelian  
- Tampilan tombol menunjukkan biaya pembelian berikutnya

# **PENUTUP**

## **Kesimpulan**

Lumina Defense: The Nightfall Siege berhasil dikembangkan sebagai game tower defense 3D di platform Roblox dengan fitur-fitur utama yang meliputi sistem wave infinite, procedural map generation, siklus siang-malam dinamis, mekanik stealth berbasis cahaya, dan empat tipe tower yang masing-masing memiliki peran taktis berbeda.

Seluruh aset 3D statis (tower, base, portal, light node) dibuat menggunakan skrip Python di Blender, sementara aset lingkungan pendukung (pohon, batu, dsb) menggunakan model dari Creator Store yang ditempatkan secara prosedural. Tidak ada aset lingkungan yang ditempatkan secara manual. setiap permainan menghasilkan tata letak map yang unik dengan 2-4 route acak.

Mekanik stealth di malam hari menjadi elemen pembeda utama: pemain tidak cukup hanya menempatkan tower ofensif, tetapi juga harus mengelola penempatan light node secara strategis untuk memastikan tower dapat menyerang musuh di malam hari. Keputusan ekonomi antara memperkuat damage tower atau membeli light node menciptakan dilema taktis yang memperkaya pengalaman bermain.

## **Saran Pengembangan**

Beberapa aspek yang dapat dikembangkan lebih lanjut untuk meningkatkan kualitas permainan:

1. Variasi tipe musuh: penambahan musuh tipe fast (kecepatan tinggi), tank (HP besar), flying (terbang melewati rute darat), atau boss pada interval wave tertentu.  
2. Multiple map: sistem pemilihan map dengan layout dan tema berbeda (misal: gurun, tundra, volcanic) yang masing-masing memiliki tantangan unik.  
3. Special abilities: setiap tower dapat memiliki ability aktif yang bisa digunakan pemain secara manual dengan cooldown (misal: slow area, burst damage, temporary reveal all stealth).  
4. Multiplayer scaling: penyesuaian jumlah musuh dan HP berdasarkan jumlah pemain agar permainan tetap menantang dalam mode co-op.  
5. Mobile support: optimalisasi kontrol touchscreen, virtual joystick untuk pergerakan kamera, dan gesture zoom yang lebih intuitif untuk perangkat mobile.  
6. Sound effects & music: penambahan audio feedback untuk setiap aksi (penempatan tower, upgrade, serangan, wave start, kematian musuh) serta background music yang berubah mengikuti siklus siang-malam.