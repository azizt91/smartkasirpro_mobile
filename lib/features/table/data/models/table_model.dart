class TableModel {
  final int id;
  final String namaMeja;
  final String status;

  TableModel({
    required this.id,
    required this.namaMeja,
    required this.status,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'],
      namaMeja: json['nama_meja'] ?? '',
      status: json['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_meja': namaMeja,
      'status': status,
    };
  }
}
