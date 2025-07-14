class PaymentEntry {
  String? name;
  String? owner;
  String? creation;
  String? modified;
  String? modifiedBy;
  int? docstatus;
  int? idx;
  String? namingSeries;
  String? paymentType;
  String? postingDate;
  String? company;
  String? modeOfPayment;
  String? partyType;
  String? party;
  String? partyName;
  String? paidFrom;
  String? paidTo;
  double? paidAmount;
  String? status;
  String? remarks;
  bool? pdcCleared;

  PaymentEntry({
    this.name,
    this.owner,
    this.creation,
    this.modified,
    this.modifiedBy,
    this.docstatus,
    this.idx,
    this.namingSeries,
    this.paymentType,
    this.postingDate,
    this.company,
    this.modeOfPayment,
    this.partyType,
    this.party,
    this.partyName,
    this.paidFrom,
    this.paidTo,
    this.paidAmount,
    this.status,
    this.remarks,
    this.pdcCleared,
  });

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    return PaymentEntry(
      name: json['name'],
      owner: json['owner'],
      creation: json['creation'],
      modified: json['modified'],
      modifiedBy: json['modified_by'],
      docstatus: json['docstatus'],
      idx: json['idx'],
      namingSeries: json['naming_series'],
      paymentType: json['payment_type'],
      postingDate: json['posting_date'],
      company: json['company'],
      modeOfPayment: json['mode_of_payment'],
      partyType: json['party_type'],
      party: json['party'],
      partyName: json['party_name'],
      paidFrom: json['paid_from'],
      paidTo: json['paid_to'],
      paidAmount: json['paid_amount'] != null
          ? json['paid_amount'].toDouble()
          : null,
      status: json['status'],
      remarks: json['remarks'],
      pdcCleared: json['pdc_cleared'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'owner': owner,
      'creation': creation,
      'modified': modified,
      'modified_by': modifiedBy,
      'docstatus': docstatus,
      'idx': idx,
      'naming_series': namingSeries,
      'payment_type': paymentType,
      'posting_date': postingDate,
      'company': company,
      'mode_of_payment': modeOfPayment,
      'party_type': partyType,
      'party': party,
      'party_name': partyName,
      'paid_from': paidFrom,
      'paid_to': paidTo,
      'paid_amount': paidAmount,
      'status': status,
      'remarks': remarks,
      'pdc_cleared': pdcCleared,
    };
  }
}
