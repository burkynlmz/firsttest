
class Surec {
  final int id;
  final String baslik;
  final int baslangicSoruId;

  Surec({
    required this.id, 
    required this.baslik, 
    required this.baslangicSoruId
  });

  // Veritabanından gelen Map verisini (Veritabanı dili) Sınıfa (Dart dili) çevirir
  factory Surec.fromMap(Map<String, dynamic> map) {
    return Surec(
      id: map['Surec_ID'],
      baslik: map['Baslik'],
      baslangicSoruId: map['Baslangic_Soru_ID'],
    );
  }
}

class Soru {
  final int id;
  final int surecId;
  final String metin;
  final int? evetSoruId;  
  final int? hayirSoruId; 
  final int? ilgiliBelgeId;
  final String? sonucTipi; 

  Soru({
    required this.id,
    required this.surecId,
    required this.metin,
    this.evetSoruId,
    this.hayirSoruId,
    this.ilgiliBelgeId,
    this.sonucTipi,
  });

  factory Soru.fromMap(Map<String, dynamic> map) {
    return Soru(
      id: map['Soru_ID'],
      surecId: map['Surec_ID'],
      metin: map['Soru_Metni'],
      // SQLite bazen null yerine 0 döndürebilir, bunu kontrol altına alıyoruz:
      evetSoruId: (map['Cevap_Evet_Soru_ID'] == 0) ? null : map['Cevap_Evet_Soru_ID'],
      hayirSoruId: (map['Cevap_Hayir_Soru_ID'] == 0) ? null : map['Cevap_Hayir_Soru_ID'],
      ilgiliBelgeId: (map['Ilgili_Belge_ID'] == 0) ? null : map['Ilgili_Belge_ID'],
      sonucTipi: map['Sonuc_Tipi'],
    );
  }
}

class Belge {
  final int id;
  final String ad;
  final String? not;

  Belge({
    required this.id, 
    required this.ad, 
    this.not
  });

  factory Belge.fromMap(Map<String, dynamic> map) {
    return Belge(
      id: map['Belge_ID'],
      ad: map['Belge_Adi'] ?? 'İsimsiz Belge', 
      not: map['Gereklilik_Notu'], 
    );
  }
}

class Oturum {
  final int? id; // Yeni oluşturulurken ID henüz yoktur, o yüzden nullable
  final int surecId;
  final int soruId;
  final String verilenCevap;
  final String cevapTarihi;
  final int aktifMi;

  Oturum({
    this.id,
    required this.surecId,
    required this.soruId,
    required this.verilenCevap,
    required this.cevapTarihi,
    required this.aktifMi,
  });

  factory Oturum.fromMap(Map<String, dynamic> map) {
    return Oturum(
      id: map['Oturum_ID'],
      surecId: map['Surec_ID'],
      soruId: map['Soru_ID'],
      verilenCevap: map['Verilen_Cevap'],
      cevapTarihi: map['Cevap_Tarihi'],
      aktifMi: map['Aktif_Mi'],
    );
  }

  // Veritabanına kaydet Sınıfı -> Map
  Map<String, dynamic> toMap() {
    return {
      'Surec_ID': surecId,
      'Soru_ID': soruId,
      'Verilen_Cevap': verilenCevap,
      'Cevap_Tarihi': cevapTarihi,
      'Aktif_Mi': aktifMi,
    };
  }
}