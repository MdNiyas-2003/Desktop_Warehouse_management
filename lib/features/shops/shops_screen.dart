import 'package:flutter/material.dart';

import '../../core/network/backend_api.dart';
import '../../core/theme/app_colors.dart';
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
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _CreateCustomerDialog(),
    );

    if (result == null) return;

    try {
      await _api.createCustomer({
        'companyName': result['companyName'],
        'ownerName': result['ownerName'],
        'mobile': result['mobile'],
        'email': result['email'],
        'gstin': result['gstin'],
        'region': result['region'],
        'address': result['address'],
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save customer in backend. ($e)')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _shopsFuture = _api.getCustomers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customer saved successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _shopsFuture,
      builder: (context, snapshot) {
        final shops = snapshot.data ?? const <Map<String, dynamic>>[];
        final rows = shops.isEmpty
            ? _fallbackRows
            : shops
                  .map(
                    (shop) => [
                      TableTextCell(
                        (shop['companyName'] ?? shop['shopName'] ?? '-')
                            .toString(),
                        compact: true,
                      ),
                      TableTextCell(
                        (shop['ownerName'] ?? '-').toString(),
                        compact: true,
                      ),
                      TableTextCell(
                        (shop['mobile'] ?? '-').toString(),
                        compact: true,
                      ),
                      TableTextCell(
                        (shop['region'] ?? '-').toString(),
                        compact: true,
                      ),
                      TableTextCell(
                        (shop['address'] ?? '-').toString(),
                        compact: true,
                      ),
                      const _RowActions(),
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
                  'Owner Name',
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

final List<List<Widget>> _fallbackRows = const [
  [
    TableTextCell('Sharma Store', compact: true),
    TableTextCell('Rajesh Sharma', compact: true),
    TableTextCell('9876543210', compact: true),
    TableTextCell('North', compact: true),
    TableTextCell('123, MG Road, Delhi', compact: true),
    _RowActions(),
  ],
  [
    TableTextCell('Gupta General Store', compact: true),
    TableTextCell('Amit Gupta', compact: true),
    TableTextCell('9876543211', compact: true),
    TableTextCell('North', compact: true),
    TableTextCell('56, Model Town, Delhi', compact: true),
    _RowActions(),
  ],
  [
    TableTextCell('Kumar Provision', compact: true),
    TableTextCell('Suresh Kumar', compact: true),
    TableTextCell('9876543212', compact: true),
    TableTextCell('South', compact: true),
    TableTextCell('18, Bannerghatta Road', compact: true),
    _RowActions(),
  ],
];

class _CreateCustomerDialog extends StatefulWidget {
  const _CreateCustomerDialog();

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

  String? _businessType;
  String? _state;
  bool _sameBillingAddress = true;
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
                            'Add Customer / Company Information',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 33,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter company details to create a new customer',
                            style: Theme.of(context).textTheme.bodyMedium,
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
                            label: 'Company Details',
                            icon: Icons.apartment_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.companyDetails,
                            onTap: () => _selectSection(
                              _CustomerDialogSection.companyDetails,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _StepMenuTile(
                            label: 'Contact Person',
                            icon: Icons.person_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.contactPerson,
                            onTap: () => _selectSection(
                              _CustomerDialogSection.contactPerson,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _StepMenuTile(
                            label: 'Address',
                            icon: Icons.location_on_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.address,
                            onTap: () =>
                                _selectSection(_CustomerDialogSection.address),
                          ),
                          const SizedBox(height: 8),
                          _StepMenuTile(
                            label: 'Business Details',
                            icon: Icons.badge_rounded,
                            selected:
                                _activeSection ==
                                _CustomerDialogSection.businessDetails,
                            onTap: () => _selectSection(
                              _CustomerDialogSection.businessDetails,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _StepMenuTile(
                            label: 'Payment & Credit',
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
                            label: 'Documents',
                            icon: Icons.description_rounded,
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
                              _field(
                                'Company / Business Name *',
                                _companyController,
                                required: true,
                              ),
                              _field(
                                'Short Name (Optional)',
                                _shortNameController,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _threeFields(
                              _dropdownField(
                                label: 'Business Type *',
                                value: _businessType,
                                items: _businessTypes,
                                onChanged: (v) =>
                                    setState(() => _businessType = v),
                                required: true,
                              ),
                              _field('GST Number', _gstinController),
                              _field('PAN Number (Optional)', _panController),
                            ),
                            const SizedBox(height: 10),
                            _threeFields(
                              _field(
                                'Owner Name *',
                                _ownerController,
                                required: true,
                              ),
                              _field(
                                'Company Email',
                                _emailController,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              _field(
                                'Phone Number *',
                                _mobileController,
                                keyboardType: TextInputType.phone,
                                required: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _twoFields(
                              _field('Website (Optional)', _websiteController),
                              _field(
                                'Business Registration Number (Optional)',
                                _registrationController,
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
                              _field(
                                'Address Line 2 (Optional)',
                                _addressLine2Controller,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _threeFields(
                              _field('City *', _cityController, required: true),
                              _dropdownField(
                                label: 'State *',
                                value: _state,
                                items: _states,
                                onChanged: (v) => setState(() => _state = v),
                                required: true,
                              ),
                              _field(
                                'Pin Code *',
                                _pinCodeController,
                                keyboardType: TextInputType.number,
                                required: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Use same address for Billing',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch.adaptive(
                                  value: _sameBillingAddress,
                                  onChanged: (value) {
                                    setState(() => _sameBillingAddress = value);
                                  },
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
                                      'Owner Name *',
                                      _ownerController,
                                      required: true,
                                    ),
                                    _field(
                                      'Mobile *',
                                      _mobileController,
                                      keyboardType: TextInputType.phone,
                                      required: true,
                                    ),
                                    _field(
                                      'Email',
                                      _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
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
                                    _field('GST Number', _gstinController),
                                    _field('PAN Number', _panController),
                                    _field(
                                      'Registration Number',
                                      _registrationController,
                                    ),
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
                                  _field(
                                    'Payment Terms (Optional)',
                                    _paymentTermsController,
                                    maxLines: 2,
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
                                  _field(
                                    'Document Reference (Optional)',
                                    _documentsController,
                                    maxLines: 2,
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
                        Checkbox(
                          value: _addAnotherAfterSave,
                          onChanged: (value) {
                            setState(
                              () => _addAnotherAfterSave = value ?? false,
                            );
                          },
                        ),
                        const Text(
                          'Add Another After Save',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                          'companyName': _companyController.text.trim(),
                          'ownerName': _ownerController.text.trim(),
                          'mobile': _mobileController.text.trim(),
                          'email': _emailController.text.trim(),
                          'gstin': _gstinController.text.trim(),
                          'region': (_state ?? '').trim(),
                          'address': address,
                        });
                      },
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Save Customer'),
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
  const _RowActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.edit_outlined, size: 18),
        SizedBox(width: 10),
        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
      ],
    );
  }
}
