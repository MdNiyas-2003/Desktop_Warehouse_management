const { query } = require('../db');

async function getCustomers(_req, res) {
    try {
        const result = await query(`SELECT id, customer_code, company_name, short_name, customer_category, business_type, industry, business_since, website, contact_person, designation, department, mobile, alternate_mobile, office_phone, whatsapp, email, address_line1, address_line2, area, landmark, city, state, country, pin_code, billing_address, shipping_address, gst_registration_type, gstin, pan, registration_no, msme_no, cin_no, fssai_no, drug_license_no, iec_code, payment_terms, payment_mode, currency, credit_days, credit_limit, price_list, assigned_salesman, sales_region, gst_certificate, pan_document, trade_license, address_proof, agreement_document, other_document, notes, status, created_at, updated_at FROM customers ORDER BY company_name;`);

        return res.json(result.rows);
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function createCustomer(req, res) {
    const {
        customerCode, companyName, shortName, customerCategory, businessType,
        industry, businessSince, website,
        contactPerson, designation, department, mobile, alternateMobile,
        officePhone, whatsapp, email,
        addressLine1, addressLine2, area, landmark, city, state, country,
        pinCode, billingAddress, shippingAddress,
        gstRegistrationType, gstin, pan, registrationNo, msmeNo, cinNo,
        fssaiNo, drugLicenseNo, iecCode,
        paymentTerms, paymentMode, currency, creditDays, creditLimit,
        priceList, assignedSalesman, salesRegion,
        gstCertificate, panDocument, tradeLicense, addressProof,
        agreementDocument, otherDocument,
        notes, status,
    } = req.body;

    if (!companyName || String(companyName).trim().length === 0) {
        return res.status(400).json({ message: 'companyName is required' });
    }

    try {
        const result = await query(
            `INSERT INTO customers ( customer_code, company_name, short_name, customer_category, business_type, industry, business_since, website, contact_person, designation, department, mobile, alternate_mobile, office_phone, whatsapp, email, address_line1, address_line2, area, landmark, city, state, country, pin_code, billing_address, shipping_address, gst_registration_type, gstin, pan, registration_no, msme_no, cin_no, fssai_no, drug_license_no, iec_code, payment_terms, payment_mode, currency, credit_days, credit_limit, price_list, assigned_salesman, sales_region, gst_certificate, pan_document, trade_license, address_proof, agreement_document, other_document, notes, status ) VALUES ( $1,$2,$3,$4,$5,$6,$7,$8, $9,$10,$11,$12,$13,$14,$15,$16, $17,$18,$19,$20,$21,$22,$23,$24,$25,$26, $27,$28,$29,$30,$31,$32,$33,$34,$35,
$36,$37,$38,$39,$40,$41,$42,$43,
$44,$45,$46,$47,$48,$49,$50,$51
)
RETURNING *`,
            [
                customerCode, companyName, shortName, customerCategory,
                businessType, industry, businessSince, website,
                contactPerson, designation, department, mobile, alternateMobile,
                officePhone, whatsapp, email,
                addressLine1, addressLine2, area, landmark, city, state, country,
                pinCode, billingAddress, shippingAddress,
                gstRegistrationType, gstin, pan, registrationNo, msmeNo, cinNo,
                fssaiNo, drugLicenseNo, iecCode,
                paymentTerms, paymentMode, currency, creditDays, creditLimit,
                priceList, assignedSalesman, salesRegion,
                gstCertificate, panDocument, tradeLicense, addressProof,
                agreementDocument, otherDocument,
                notes, status ?? 'Active',
            ]
        );

        return res.status(201).json(result.rows[0]);
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function updateCustomer(req, res) {
    const { id } = req.params;

    const {
        customerCode, companyName, shortName, customerCategory, businessType,
        industry, businessSince, website,
        contactPerson, designation, department, mobile, alternateMobile,
        officePhone, whatsapp, email,
        addressLine1, addressLine2, area, landmark, city, state, country,
        pinCode, billingAddress, shippingAddress,
        gstRegistrationType, gstin, pan, registrationNo, msmeNo, cinNo,
        fssaiNo, drugLicenseNo, iecCode,
        paymentTerms, paymentMode, currency, creditDays, creditLimit,
        priceList, assignedSalesman, salesRegion,
        gstCertificate, panDocument, tradeLicense, addressProof,
        agreementDocument, otherDocument,
        notes, status,
    } = req.body;

    try {
        const result = await query(
            `UPDATE customers SET customer_code=$1, company_name=3,
customer_category=5, industry=7, website=9, designation=11,
mobile=13, office_phone=15, email=17, address_line2=19, landmark=21, state=23, pin_code=25, shipping_address=27, gstin=29,
registration_no=31, cin_no=33,
drug_license_no=35,
payment_terms=37, currency=39, credit_limit=41,
assigned_salesman=43,
gst_certificate=45, trade_license=47, agreement_document=49,
notes=51, updated_at=NOW()
WHERE id=$52 RETURNING *`,
            [
                customerCode, companyName, shortName, customerCategory,
                businessType, industry, businessSince, website,
                contactPerson, designation, department, mobile, alternateMobile,
                officePhone, whatsapp, email,
                addressLine1, addressLine2, area, landmark, city, state, country,
                pinCode, billingAddress, shippingAddress,
                gstRegistrationType, gstin, pan, registrationNo, msmeNo, cinNo,
                fssaiNo, drugLicenseNo, iecCode,
                paymentTerms, paymentMode, currency, creditDays, creditLimit,
                priceList, assignedSalesman, salesRegion,
                gstCertificate, panDocument, tradeLicense, addressProof,
                agreementDocument, otherDocument,
                notes, status, id,
            ]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Customer not found' });
        }

        return res.json(result.rows[0]);
    } catch (error) {
        return res.status(500).json({ message: error.message });
    }
}

async function deleteCustomer(req, res) {
    const { id } = req.params;

    try {
        const result = await query(
            `DELETE FROM customers WHERE id =$1
RETURNING id`,
            [id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Customer not found' });
        }

        return res.json({ message: 'Customer deleted successfully' });
    } catch (error) {
        if (error.code === '23503') {
            return res.status(400).json({
                message: 'This customer already has orders. Delete is not allowed.',
            });
        }

        return res.status(500).json({ message: error.message });
    }
}

module.exports = {
    getCustomers,
    createCustomer,
    updateCustomer,
    deleteCustomer,
};