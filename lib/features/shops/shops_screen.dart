import 'package:flutter/material.dart';

import '../../core/network/backend_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/premium_widgets.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key, this.openCreateSignal = 0});

  final int openCreateSignal;

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  int _lastHandledCreateSignal = 0;
  final BackendApi _api = BackendApi();
  late Future<List<Map<String, dynamic>>> _shopsFuture;

  @override
  void initState() {
    super.initState();
    _shopsFuture = _api.getCustomers();
    _lastHandledCreateSignal = widget.openCreateSignal;
    if (widget.openCreateSignal > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCreateCustomerDialog();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ShopsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCreateSignal != _lastHandledCreateSignal) {
      _lastHandledCreateSignal = widget.openCreateSignal;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCreateCustomerDialog();
      });
    }
  }

  Future<void> _showCreateCustomerDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CreateCustomerDialog(),
    );

    if (result == null) return;

    try {
      await _api.createCustomer(result);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.failed(message: 'Unable to save customer in backend. ($e)');
      return;
    }

    if (!mounted) return;
    setState(() {
      _shopsFuture = _api.getCustomers();
    });
    AppSnackBar.success(message: 'Customer saved successfully.');
  }

  Future<bool?> showDeleteCustomerDialog(
    BuildContext context,
    String customerName,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xffEAF3FF), Color(0xffD8E9FF)],
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xff2F6BFF),
                    size: 30,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  "Delete Customer",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Are you sure you want to delete",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF4F8FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffD7E5FF)),
                  ),
                  child: Text(
                    customerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "This action cannot be undone.",
                  style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2F6BFF),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _shopsFuture,
      builder: (context, snapshot) {
        final shops = snapshot.data ?? const <Map<String, dynamic>>[];
        final rows = shops
            .map(
              (shop) => [
                TableTextCell(
                  (shop['company_name'] ?? '-').toString(),
                  compact: true,
                ),

                TableTextCell(
                  (shop['contact_person'] ?? '-').toString(),
                  compact: true,
                ),

                TableTextCell(
                  (shop['mobile'] ?? '-').toString(),
                  compact: true,
                ),

                TableTextCell(
                  (shop['state'] ?? shop['-']).toString(),
                  compact: true,
                ),

                TableTextCell(
                  [shop['address_line1'], shop['city']]
                      .where((e) => e != null && e.toString().isNotEmpty)
                      .join(', '),
                  compact: true,
                ),
                _RowActions(
                  shop: shop,
                  onEdit: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => _CreateCustomerDialog(customer: shop),
                    );

                    if (result == null) return;

                    await _api.updateCustomer(shop['id'], result);

                    if (!mounted) return;

                    setState(() {
                      _shopsFuture = _api.getCustomers();
                    });

                    AppSnackBar.success(
                      message: 'Customer updated successfully',
                    );
                  },
                  onDelete: () async {
                    final confirmed = await showDeleteCustomerDialog(
                      context,
                      shop['company_name'] ??
                          shop['companyName'] ??
                          'Unknown Customer',
                    );

                    if (confirmed != true) return;

                    try {
                      await _api.deleteCustomer(shop['id']);

                      if (!mounted) return;

                      setState(() {
                        _shopsFuture = _api.getCustomers();
                      });

                      AppSnackBar.success(
                        message: 'Customer deleted successfully',
                      );
                    } catch (e) {
                      if (!mounted) return;

                      AppSnackBar.failed(message: e.toString());
                    }
                  },
                ),
              ],
            )
            .toList();

        return SingleChildScrollView(
          key: const ValueKey('shops'),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Shop Management',
                subtitle:
                    'Track outlet details, contacts, regions, and assigned sales owners.',
                action: ActionButton(
                  label: 'Create Customer',
                  icon: Icons.person_add_alt_1_rounded,
                  primary: true,
                  onPressed: _showCreateCustomerDialog,
                ),
              ),
              const SizedBox(height: 18),
              SimpleTable(
                headers: const [
                  'Company / Shop',
                  'Contact Person',
                  'Mobile',
                  'Region',
                  'Address',
                  'Action',
                ],
                columnFlexes: const [18, 14, 11, 10, 30, 7],
                rows: rows,
                compact: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreateCustomerDialog extends StatefulWidget {
  const _CreateCustomerDialog({super.key, this.customer});

  final Map<String, dynamic>? customer;

  bool get isEdit => customer != null;

  @override
  State<_CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<_CreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  final _websiteController = TextEditingController();
  final _registrationController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _documentsController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _customerCodeController = TextEditingController(
    text: 'CUS-${DateTime.now().millisecondsSinceEpoch}',
  );

  final _customerCategoryController = TextEditingController();
  final _industryController = TextEditingController();
  final _businessSinceController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _billingAddressController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _alternateMobileController = TextEditingController();
  final _officePhoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _gstTypeController = TextEditingController();
  final _fssaiController = TextEditingController();
  final _drugLicenseController = TextEditingController();
  final _msmeController = TextEditingController();
  final _cinController = TextEditingController();
  final _iecController = TextEditingController();
  final _creditDaysController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _priceListController = TextEditingController();
  final _salesmanController = TextEditingController();
  final _salesRegionController = TextEditingController();
  final _gstCertificateController = TextEditingController();
  final _panDocumentController = TextEditingController();
  final _tradeLicenseController = TextEditingController();
  final _addressProofController = TextEditingController();
  final _agreementController = TextEditingController();
  final _otherDocumentController = TextEditingController();

  String? _businessType;
  String? _state;
  bool _sameBillingAddress = false;
  bool _addAnotherAfterSave = false;
  _CustomerDialogSection _activeSection = _CustomerDialogSection.companyDetails;
  final ScrollController _contentScrollController = ScrollController();
  final Map<_CustomerDialogSection, GlobalKey> _sectionKeys = {
    _CustomerDialogSection.companyDetails: GlobalKey(),
    _CustomerDialogSection.contactPerson: GlobalKey(),
    _CustomerDialogSection.address: GlobalKey(),
    _CustomerDialogSection.businessDetails: GlobalKey(),
    _CustomerDialogSection.paymentAndCredit: GlobalKey(),
    _CustomerDialogSection.documents: GlobalKey(),
    _CustomerDialogSection.notes: GlobalKey(),
  };
  String? _gstRegistrationType;
  String? _paymentTerm;
  String? _paymentMode;
  String? _currency;

  final List<String> _paymentTerms = const [
    'Advance Payment',
    'Cash on Delivery',
    'Net 7 Days',
    'Net 15 Days',
    'Net 30 Days',
    'Net 45 Days',
    'Net 60 Days',
  ];

  final List<String> _paymentModes = const [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Credit',
  ];

  final List<String> _currencies = const ['INR', 'USD', 'AED', 'EUR'];
  final List<String> _gstRegistrationTypes = const [
    'Regular',
    'Composition',
    'Unregistered',
    'SEZ',
    'Export',
  ];
  final List<String> _customerCategories = const [
    'Retailer',
    'Distributor',
    'Dealer',
    'Wholesaler',
    'Corporate',
    'Online Customer',
  ];

  final List<String> _industries = const [
    'Garments',
    'Textiles',
    'Electronics',
    'Super Market',
    'Pharmacy',
    'FMCG',
    'Restaurant',
    'Construction',
    'Automobile',
    'Others',
  ];

  String? _customerCategory;
  String? _industry;

  final List<String> _businessTypes = const [
    'Retailer',
    'Distributor',
    'Wholesaler',
    'Supermarket',
    'Pharmacy',
  ];

  final List<String> _states = const [
    'Tamil Nadu',
    'Karnataka',
    'Kerala',
    'Andhra Pradesh',
    'Maharashtra',
    'Delhi',
  ];
  @override
  void initState() {
    super.initState();

    _billingAddressController.addListener(() {
      if (_sameBillingAddress) {
        _shippingAddressController.text = _billingAddressController.text;
      }
    });

    if (!widget.isEdit) return;

    final c = widget.customer!;

    _customerCodeController.text = c['customer_code'] ?? '';
    _companyController.text = c['company_name'] ?? '';
    _shortNameController.text = c['short_name'] ?? '';
    _contactPersonController.text = c['contact_person'] ?? '';
    _mobileController.text = c['mobile'] ?? '';
    _emailController.text = c['email'] ?? '';
    _gstinController.text = c['gstin'] ?? '';
    _panController.text = c['pan'] ?? '';
    _websiteController.text = c['website'] ?? '';
    _registrationController.text = c['registration_number'] ?? '';
    _paymentTerm = c['payment_term'];
    _paymentMode = c['payment_mode'];
    _currency = c['currency'];
    _gstRegistrationType = c['gst_registration_type'];
    _state = c['state'];
    _sameBillingAddress = c['same_billing_address'] ?? true;
    _customerCategory = c['customer_category'];
    _industry = c['industry'];
    _businessType = c['business_type'];
    _addressLine1Controller.text = c['address_line_1'] ?? '';
    _addressLine2Controller.text = c['address_line_2'] ?? '';
    _cityController.text = c['city'] ?? '';
    _pinCodeController.text = c['pin_code'] ?? '';
    _billingAddressController.text = c['billing_address'] ?? '';
    _shippingAddressController.text = c['shipping_address'] ?? '';
    _ownerController.text = c['owner_name'] ?? '';
    _designationController.text = c['designation'] ?? '';
    _departmentController.text = c['department'] ?? '';
    _alternateMobileController.text = c['alternate_mobile'] ?? '';
    _officePhoneController.text = c['office_phone'] ?? '';
    _whatsappController.text = c['whatsapp_number'] ?? '';
    _fssaiController.text = c['fssai_license'] ?? '';
    _drugLicenseController.text = c['drug_license'] ?? '';
    _msmeController.text = c['msme_number'] ?? '';
    _cinController.text = c['cin_number'] ?? '';
    _iecController.text = c['iec_code'] ?? '';
    _creditDaysController.text = c['credit_days']?.toString() ?? '';
    _creditLimitController.text = c['credit_limit']?.toString() ?? '';
    _priceListController.text = c['price_list'] ?? '';
    _salesmanController.text = c['assigned_salesman'] ?? '';
    _salesRegionController.text = c['sales_region'] ?? '';
    _gstCertificateController.text = c['gst_certificate'] ?? '';
    _panDocumentController.text = c['pan_document'] ?? '';
    _tradeLicenseController.text = c['trade_license'] ?? '';
    _addressProofController.text = c['address_proof'] ?? '';
    _agreementController.text = c['customer_agreement'] ?? '';
    _otherDocumentController.text = c['other_documents'] ?? '';
    _notesController.text = c['notes'] ?? '';
    _areaController.text = c['area'] ?? '';
    _landmarkController.text = c['landmark'] ?? '';
    _countryController.text = c['country'] ?? 'India';
    _businessSinceController.text = c['business_since'] ?? '';
    _customerCategoryController.text = c['customer_category'] ?? '';
    _industryController.text = c['industry'] ?? '';
    _paymentTermsController.text = c['payment_terms'] ?? '';
    _documentsController.text = c['documents'] ?? '';
    _notesController.text = c['notes'] ?? '';
    _ownerController.text = c['owner_name'] ?? '';
    _mobileController.text = c['mobile'] ?? '';
    _emailController.text = c['email'] ?? '';
    _gstinController.text = c['gstin'] ?? '';
    _panController.text = c['pan'] ?? '';
    _websiteController.text = c['website'] ?? '';
  }

  @override
  void dispose() {
    _companyController.dispose();
    _shortNameController.dispose();
    _ownerController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _websiteController.dispose();
    _registrationController.dispose();
    _paymentTermsController.dispose();
    _documentsController.dispose();
    _notesController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _pinCodeController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  void _selectSection(_CustomerDialogSection section) {
    setState(() => _activeSection = section);
    final key = _sectionKeys[section];
    final targetContext = key?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 760),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2A0B1835),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.corporate_fare_rounded,
                        color: Color(0xFF2E5BFF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEdit
                                ? 'Edit Customer'
                                : 'Add Customer / Company Information',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter company details to create a new customer',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 24),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 190,
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFF),
                        border: Border(
                          right: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _StepMenuTile(
                            label: 'Company Profile',
                            icon: Icons.business_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.companyDetails,
                            onTap: () => _selectSection(
                              _CustomerDialogSection.companyDetails,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _StepMenuTile(
                            label: 'Locations',
                            icon: Icons.location_city_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.address,
                            onTap: () =>
                                _selectSection(_CustomerDialogSection.address),
                          ),
                          const SizedBox(height: 8),
                          _StepMenuTile(
                            label: 'Contacts',
                            icon: Icons.contacts_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.contactPerson,
                            onTap: () => _selectSection(
                              _CustomerDialogSection.contactPerson,
                            ),
                          ),

                          const SizedBox(height: 8),

                          _StepMenuTile(
                            label: 'Tax & Business',
                            icon: Icons.receipt_long_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.businessDetails,
                            onTap: () => _selectSection(
                              _CustomerDialogSection.businessDetails,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _StepMenuTile(
                            label: 'Finance',
                            icon: Icons.account_balance_wallet_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.paymentAndCredit,
                            onTap: () => _selectSection(
                              _CustomerDialogSection.paymentAndCredit,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _StepMenuTile(
                            label: 'Attachments',
                            icon: Icons.attach_file_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.documents,
                            onTap: () => _selectSection(
                              _CustomerDialogSection.documents,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _StepMenuTile(
                            label: 'Notes',
                            icon: Icons.sticky_note_2_rounded,
                            selected:
                                _activeSection == _CustomerDialogSection.notes,
                            onTap: () =>
                                _selectSection(_CustomerDialogSection.notes),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _contentScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                              key:
                                  _sectionKeys[_CustomerDialogSection
                                      .companyDetails],
                              child: const SizedBox.shrink(),
                            ),
                            Text(
                              'Company Details',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 132,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _twoFields(
                              _field('Customer Code', _customerCodeController),
                              _field(
                                'Company / Business Name *',
                                _companyController,
                                required: true,
                              ),
                            ),
                            const SizedBox(height: 10),

                            _threeFields(
                              _field('Short Name', _shortNameController),

                              _dropdownField(
                                label: 'Customer Category *',
                                value: _customerCategory,
                                items: _customerCategories,
                                onChanged: (v) {
                                  setState(() => _customerCategory = v);
                                },
                                required: true,
                              ),

                              _dropdownField(
                                label: 'Business Type *',
                                value: _businessType,
                                items: _businessTypes,
                                onChanged: (v) {
                                  setState(() => _businessType = v);
                                },
                                required: true,
                              ),
                            ),
                            const SizedBox(height: 10),

                            _threeFields(
                              _dropdownField(
                                label: 'Industry',
                                value: _industry,
                                items: _industries,
                                onChanged: (v) {
                                  setState(() => _industry = v);
                                },
                              ),

                              _field(
                                'Business Since',
                                _businessSinceController,
                              ),

                              _field('Website', _websiteController),
                            ),

                            const SizedBox(height: 10),

                            _threeFields(
                              _field('GST Number', _gstinController),

                              _field('PAN Number', _panController),

                              _field(
                                'Registration Number',
                                _registrationController,
                              ),
                            ),
                            const SizedBox(height: 10),

                            _threeFields(
                              _field(
                                'Company Email',
                                _emailController,
                                keyboardType: TextInputType.emailAddress,
                              ),

                              _field(
                                'Phone Number',
                                _mobileController,
                                keyboardType: TextInputType.phone,
                                required: true,
                              ),

                              _field(
                                'Alternate Mobile',
                                TextEditingController(),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(height: 14),

                            Divider(
                              color: AppColors.border.withValues(alpha: 0.9),
                              height: 1,
                            ),
                            const SizedBox(height: 12),
                            KeyedSubtree(
                              key: _sectionKeys[_CustomerDialogSection.address],
                              child: const SizedBox.shrink(),
                            ),
                            Text(
                              'Company Address',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),

                            _twoFields(
                              _field(
                                'Address Line 1 *',
                                _addressLine1Controller,
                                required: true,
                              ),
                              _field('Address Line 2', _addressLine2Controller),
                            ),

                            const SizedBox(height: 10),

                            _threeFields(
                              _field('Area / Locality', _areaController),
                              _field('Landmark', _landmarkController),
                              _field('City *', _cityController, required: true),
                            ),

                            const SizedBox(height: 10),

                            _threeFields(
                              _dropdownField(
                                label: 'State *',
                                value: _state,
                                items: _states,
                                onChanged: (v) => setState(() => _state = v),
                                required: true,
                              ),
                              _field('Country', _countryController),
                              _field(
                                'Pin Code *',
                                _pinCodeController,
                                keyboardType: TextInputType.number,
                                required: true,
                              ),
                            ),

                            const SizedBox(height: 10),

                            _twoFields(
                              _field(
                                'Billing Address',
                                _billingAddressController,
                                maxLines: 2,
                              ),
                              _field(
                                'Shipping Address',
                                _shippingAddressController,
                                maxLines: 2,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                const Text(
                                  'Billing address same as shipping',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                Transform.scale(
                                  scale:
                                      0.50, // Try 0.75 or 0.70 if you want it even smaller
                                  child: Switch(
                                    value: _sameBillingAddress,
                                    onChanged: (value) {
                                      setState(() {
                                        _sameBillingAddress = value;

                                        if (value) {
                                          _shippingAddressController.text =
                                              _billingAddressController.text;
                                        } else {
                                          _shippingAddressController.clear();
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),
                            KeyedSubtree(
                              key:
                                  _sectionKeys[_CustomerDialogSection
                                      .contactPerson],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Contact Person',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _field(
                                      'Contact Person Name *',
                                      _contactPersonController,
                                      required: true,
                                    ),
                                    _field(
                                      'Designation',
                                      _designationController,
                                    ),
                                    _field('Department', _departmentController),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _field(
                                      'Mobile Number *',
                                      _mobileController,
                                      keyboardType: TextInputType.phone,
                                      required: true,
                                    ),
                                    _field(
                                      'Alternate Mobile',
                                      _alternateMobileController,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    _field(
                                      'Office Phone',
                                      _officePhoneController,
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _field(
                                      'Email Address',
                                      _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    _field(
                                      'WhatsApp Number',
                                      _whatsappController,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            KeyedSubtree(
                              key:
                                  _sectionKeys[_CustomerDialogSection
                                      .businessDetails],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Business Details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _dropdownField(
                                      label: 'GST Registration Type',
                                      value: _gstRegistrationType,
                                      items: _gstRegistrationTypes,
                                      onChanged: (v) {
                                        setState(
                                          () => _gstRegistrationType = v,
                                        );
                                      },
                                    ),
                                    _field('GST Number', _gstinController),
                                    _field('PAN Number', _panController),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _field(
                                      'Business Registration No.',
                                      _registrationController,
                                    ),
                                    _field(
                                      'MSME / UDYAM Number',
                                      _msmeController,
                                    ),
                                    _field('CIN Number', _cinController),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _field(
                                      'FSSAI License No.',
                                      _fssaiController,
                                    ),
                                    _field(
                                      'Drug License No.',
                                      _drugLicenseController,
                                    ),
                                    _field('IEC Code', _iecController),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            KeyedSubtree(
                              key:
                                  _sectionKeys[_CustomerDialogSection
                                      .paymentAndCredit],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment & Credit',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _dropdownField(
                                      label: 'Payment Terms',
                                      value: _paymentTerm,
                                      items: _paymentTerms,
                                      onChanged: (v) {
                                        setState(() => _paymentTerm = v);
                                      },
                                    ),

                                    _dropdownField(
                                      label: 'Preferred Payment Mode',
                                      value: _paymentMode,
                                      items: _paymentModes,
                                      onChanged: (v) {
                                        setState(() => _paymentMode = v);
                                      },
                                    ),

                                    _dropdownField(
                                      label: 'Currency',
                                      value: _currency,
                                      items: _currencies,
                                      onChanged: (v) {
                                        setState(() => _currency = v);
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _field(
                                      'Credit Days',
                                      _creditDaysController,
                                      keyboardType: TextInputType.number,
                                    ),

                                    _field(
                                      'Credit Limit',
                                      _creditLimitController,
                                      keyboardType: TextInputType.number,
                                    ),

                                    _field('Price List', _priceListController),
                                  ),

                                  const SizedBox(height: 10),

                                  _twoFields(
                                    _field(
                                      'Assigned Salesman',
                                      _salesmanController,
                                    ),

                                    _field(
                                      'Sales Region',
                                      _salesRegionController,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            KeyedSubtree(
                              key:
                                  _sectionKeys[_CustomerDialogSection
                                      .documents],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Documents',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _field(
                                      'GST Certificate',
                                      _gstCertificateController,
                                    ),

                                    _field(
                                      'PAN Document',
                                      _panDocumentController,
                                    ),

                                    _field(
                                      'Trade License',
                                      _tradeLicenseController,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  _threeFields(
                                    _field(
                                      'Address Proof',
                                      _addressProofController,
                                    ),

                                    _field(
                                      'Customer Agreement',
                                      _agreementController,
                                    ),

                                    _field(
                                      'Other Documents',
                                      _otherDocumentController,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            KeyedSubtree(
                              key: _sectionKeys[_CustomerDialogSection.notes],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 10),
                                  _field(
                                    'Notes (Optional)',
                                    _notesController,
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Row(
                      children: [
                        // Checkbox(
                        //   value: _addAnotherAfterSave,
                        //   onChanged: (value) {
                        //     setState(
                        //       () => _addAnotherAfterSave = value ?? false,
                        //     );
                        //   },
                        // ),
                        // const Text(
                        //   'Add Another After Save',
                        //   style: TextStyle(
                        //     color: AppColors.textMuted,
                        //     fontWeight: FontWeight.w600,
                        //   ),
                        // ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        final address = [
                          _addressLine1Controller.text.trim(),
                          _addressLine2Controller.text.trim(),
                          _cityController.text.trim(),
                          _state ?? '',
                          _pinCodeController.text.trim(),
                        ].where((e) => e.isNotEmpty).join(', ');

                        Navigator.of(context).pop({
                          // Company
                          'customerCode': _customerCodeController.text.trim(),
                          'companyName': _companyController.text.trim(),
                          'shortName': _shortNameController.text.trim(),
                          'customerCategory': _customerCategory ?? '',
                          'businessType': _businessType ?? '',
                          'industry': _industry ?? '',
                          'businessSince': _businessSinceController.text.trim(),
                          'website': _websiteController.text.trim(),

                          // Contact
                          'contactPerson': _contactPersonController.text.trim(),
                          'designation': _designationController.text.trim(),
                          'department': _departmentController.text.trim(),
                          'mobile': _mobileController.text.trim(),
                          'alternateMobile': _alternateMobileController.text
                              .trim(),
                          'officePhone': _officePhoneController.text.trim(),
                          'whatsapp': _whatsappController.text.trim(),
                          'email': _emailController.text.trim(),

                          // Address
                          'addressLine1': _addressLine1Controller.text.trim(),
                          'addressLine2': _addressLine2Controller.text.trim(),
                          'area': _areaController.text.trim(),
                          'landmark': _landmarkController.text.trim(),
                          'city': _cityController.text.trim(),
                          'state': _state ?? '',
                          'country': _countryController.text.trim(),
                          'pinCode': _pinCodeController.text.trim(),
                          'billingAddress': _billingAddressController.text
                              .trim(),
                          'shippingAddress': _shippingAddressController.text
                              .trim(),

                          // Business
                          'gstRegistrationType': _gstRegistrationType ?? '',
                          'gstin': _gstinController.text.trim(),
                          'pan': _panController.text.trim(),
                          'registrationNo': _registrationController.text.trim(),
                          'msmeNo': _msmeController.text.trim(),
                          'cinNo': _cinController.text.trim(),
                          'fssaiNo': _fssaiController.text.trim(),
                          'drugLicenseNo': _drugLicenseController.text.trim(),
                          'iecCode': _iecController.text.trim(),

                          // Finance
                          'paymentTerms': _paymentTerm ?? '',
                          'paymentMode': _paymentMode ?? '',
                          'currency': _currency ?? 'INR',
                          'creditDays':
                              int.tryParse(_creditDaysController.text) ?? 0,
                          'creditLimit':
                              double.tryParse(_creditLimitController.text) ?? 0,
                          'priceList': _priceListController.text.trim(),
                          'assignedSalesman': _salesmanController.text.trim(),
                          'salesRegion': _salesRegionController.text.trim(),

                          // Documents
                          'gstCertificate': _gstCertificateController.text
                              .trim(),
                          'panDocument': _panDocumentController.text.trim(),
                          'tradeLicense': _tradeLicenseController.text.trim(),
                          'addressProof': _addressProofController.text.trim(),
                          'agreementDocument': _agreementController.text.trim(),
                          'otherDocument': _otherDocumentController.text.trim(),

                          // Others
                          'notes': _notesController.text.trim(),
                          'status': 'Active',
                        });
                      },
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: Text(widget.isEdit ? 'Update' : 'Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twoFields(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(flex: 2, child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _threeFields(Widget one, Widget two, Widget three) {
    return Row(
      children: [
        Expanded(child: one),
        const SizedBox(width: 10),
        Expanded(child: two),
        const SizedBox(width: 10),
        Expanded(child: three),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, isDense: true),
      validator: (value) {
        if (required && (value ?? '').trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }
}

class _StepMenuTile extends StatelessWidget {
  const _StepMenuTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFBFD0FF) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.text,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CustomerDialogSection {
  companyDetails,
  contactPerson,
  address,
  businessDetails,
  paymentAndCredit,
  documents,
  notes,
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    super.key,
    required this.shop,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> shop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onEdit,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.edit_outlined, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onDelete,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }
}
