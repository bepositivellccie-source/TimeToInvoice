import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../models/invoice_data.dart';

/// Génère le XML Factur-X conforme EN 16931 (profil MINIMUM).
/// Structure CII (Cross-Industry Invoice) — ~40 lignes.
///
/// Référence : https://fnfe-mpe.org/factur-x/
String buildFacturXml(InvoiceData inv) {
  final dateFmt = DateFormat('yyyyMMdd');
  final issueDate = dateFmt.format(inv.issueDate);
  final dueDate =
      dateFmt.format(inv.issueDate.add(Duration(days: inv.paymentDays)));

  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');

  builder.element(
    'rsm:CrossIndustryInvoice',
    namespaces: {
      'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100': 'rsm',
      'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100':
          'ram',
      'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100': 'udt',
    },
    nest: () {
      // ── ExchangedDocumentContext ──
      builder.element('rsm:ExchangedDocumentContext', nest: () {
        builder.element('ram:GuidelineSpecifiedDocumentContextParameter',
            nest: () {
          builder.element('ram:ID',
              nest: 'urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:minimum');
        });
      });

      // ── ExchangedDocument ──
      builder.element('rsm:ExchangedDocument', nest: () {
        builder.element('ram:ID', nest: inv.invoiceNumber);
        builder.element('ram:TypeCode', nest: '380'); // Facture commerciale
        builder.element('ram:IssueDateTime', nest: () {
          builder.element('udt:DateTimeString',
              attributes: {'format': '102'}, nest: issueDate);
        });
      });

      // ── SupplyChainTradeTransaction ──
      builder.element('rsm:SupplyChainTradeTransaction', nest: () {
        // ApplicableHeaderTradeAgreement
        builder.element('ram:ApplicableHeaderTradeAgreement', nest: () {
          // Vendeur
          builder.element('ram:SellerTradeParty', nest: () {
            builder.element('ram:Name', nest: inv.sellerName);
            if (inv.sellerSiret != null) {
              builder.element('ram:SpecifiedLegalOrganization', nest: () {
                builder.element('ram:ID',
                    attributes: {'schemeID': '0002'},
                    nest: inv.sellerSiret);
              });
            }
            if (inv.sellerAddress != null) {
              builder.element('ram:PostalTradeAddress', nest: () {
                builder.element('ram:LineOne', nest: inv.sellerAddress);
                builder.element('ram:CountryID', nest: 'FR');
              });
            }
          });
          // Acheteur
          builder.element('ram:BuyerTradeParty', nest: () {
            builder.element('ram:Name', nest: inv.buyerName);
            if (inv.buyerSiret != null) {
              builder.element('ram:SpecifiedLegalOrganization', nest: () {
                builder.element('ram:ID',
                    attributes: {'schemeID': '0002'},
                    nest: inv.buyerSiret);
              });
            }
          });
        });

        // ApplicableHeaderTradeDelivery (obligatoire même vide)
        builder.element('ram:ApplicableHeaderTradeDelivery');

        // ApplicableHeaderTradeSettlement
        builder.element('ram:ApplicableHeaderTradeSettlement', nest: () {
          builder.element('ram:InvoiceCurrencyCode', nest: inv.currency);
          builder.element(
              'ram:SpecifiedTradeSettlementHeaderMonetarySummation', nest: () {
            builder.element('ram:TaxBasisTotalAmount',
                attributes: {'currencyID': inv.currency},
                nest: inv.totalHT.toStringAsFixed(2));
            builder.element('ram:TaxTotalAmount',
                attributes: {'currencyID': inv.currency},
                nest: inv.tva.toStringAsFixed(2));
            builder.element('ram:GrandTotalAmount',
                attributes: {'currencyID': inv.currency},
                nest: inv.totalTTC.toStringAsFixed(2));
            builder.element('ram:DuePayableAmount',
                attributes: {'currencyID': inv.currency},
                nest: inv.totalTTC.toStringAsFixed(2));
          });
          builder.element('ram:SpecifiedTradePaymentTerms', nest: () {
            builder.element('ram:DueDateDateTime', nest: () {
              builder.element('udt:DateTimeString',
                  attributes: {'format': '102'}, nest: dueDate);
            });
          });
        });
      });
    },
  );

  return builder.buildDocument().toXmlString(pretty: true);
}
