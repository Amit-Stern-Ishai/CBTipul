import Foundation
import Testing
import UIKit
@testable import CBTipul

struct PatientInvitationShareTests {
    private let therapistName = "דנה כהן"
    private let invitationUrl = "https://cbtipul.com/invite/opaque-token"

    @Test func shareMessageIncludesTherapistNameAndExactUrl() {
        let body = L10n.patientInvitationShareMessage(
            therapistName: therapistName,
            invitationUrl: invitationUrl
        )
        #expect(body.contains(therapistName))
        #expect(body.contains(invitationUrl))
        #expect(body.contains("לפתיחת ההזמנה:"))
        #expect(body.components(separatedBy: invitationUrl).count == 2)
    }

    @Test func shareMessageUsesNewCopyAndDropsBareWording() {
        let body = L10n.patientInvitationShareMessage(
            therapistName: therapistName,
            invitationUrl: invitationUrl
        )
        #expect(body.contains("דרך האפליקציה ניתן למלא שאלוני מצב רוח ויומני מחשבות ולצפות בתכנים שנשלחו אליך כחלק מהטיפול."))
        #expect(body.contains("ההזמנה אישית ומיועדת עבורך בלבד."))
        #expect(body.contains("\(therapistName) הזמין/ה אותך להתחבר ל-CBTipul."))
        #expect(!body.contains("הוזמנת להתחבר ל-CBTipul על ידי"))
        #expect(!body.contains("להתחברות:"))
    }

    @Test func shareSubjectIsInvitationToConnect() {
        #expect(L10n.patientInvitationShareSubject == "הזמנה להתחבר ל-CBTipul")
        let item = InvitationShareActivityItem(
            body: L10n.patientInvitationShareMessage(
                therapistName: therapistName,
                invitationUrl: invitationUrl
            ),
            subject: L10n.patientInvitationShareSubject
        )
        #expect(item.subject == L10n.patientInvitationShareSubject)
        #expect(item.body.contains(invitationUrl))
    }

    @Test func shareContentOmitsPatientIdentifiersAndClinicalDetails() {
        let body = L10n.patientInvitationShareMessage(
            therapistName: therapistName,
            invitationUrl: invitationUrl
        )
        #expect(!body.contains("patientId"))
        #expect(!body.contains("patient_id"))
        #expect(!body.contains("Supabase"))
        #expect(!body.localizedStandardContains("אבחנה"))
        #expect(!body.localizedStandardContains("שאלון GAD"))
        #expect(L10n.invitePreviewTherapistLine(therapistName).contains(therapistName))
        #expect(L10n.invitePreviewExplanation.contains("שאלוני מצב רוח ויומני מחשבות"))
    }

    @Test func gmailCopyIsPlainTextWithOneExactLink() {
        let body = L10n.patientInvitationEmailMessage(therapistName: therapistName, invitationUrl: invitationUrl)
        #expect(body.contains(therapistName))
        #expect(body.components(separatedBy: invitationUrl).count == 2)
        #expect(body.contains("\n" + invitationUrl + "\n"))
        #expect(body.contains("•"))
        #expect(!body.contains("<html"))
    }

    @Test func emailEscapesDynamicContentAndPreservesLinkQuery() {
        let html = L10n.patientInvitationEmailHTML(
            therapistName: "דנה <כהן> & \"צוות\"",
            invitationUrl: "https://cbtipul.com/invite/example?first=1&second=2"
        )
        #expect(html.contains("דנה &lt;כהן&gt; &amp; &quot;צוות&quot;"))
        #expect(html.contains("href=\"https://cbtipul.com/invite/example?first=1&amp;second=2\""))
        #expect(html.contains("dir=\"rtl\""))
        #expect(html.contains("פתיחת ההזמנה"))
        #expect(!html.contains("<כהן>"))
    }

    @Test @MainActor func mailReceivesHTMLAndGmailReceivesNonemptyText() {
        let html = L10n.patientInvitationEmailHTML(therapistName: therapistName, invitationUrl: invitationUrl)
        let item = InvitationShareActivityItem(body: "plain invitation", subject: "subject", htmlBody: html, emailBody: "email invitation")
        let controller = UIActivityViewController(activityItems: [], applicationActivities: nil)
        #expect(item.activityViewController(controller, itemForActivityType: .mail) as? String == html)
        #expect(item.activityViewController(controller, dataTypeIdentifierForActivityType: .mail) == "public.html")
        let gmail = UIActivity.ActivityType(rawValue: "com.google.Gmail.ShareExtension")
        #expect(item.activityViewController(controller, itemForActivityType: gmail) as? String == "email invitation")
        #expect(item.activityViewController(controller, dataTypeIdentifierForActivityType: gmail) == "public.plain-text")
        #expect(item.activityViewController(controller, subjectForActivityType: gmail) == "subject")
        let plain = InvitationShareActivityItem(body: "plain invitation", subject: "subject")
        #expect(plain.activityViewController(controller, itemForActivityType: gmail) as? String == "plain invitation")
        #expect(plain.activityViewController(controller, dataTypeIdentifierForActivityType: gmail) == "public.plain-text")
        for target: UIActivity.ActivityType? in [.message, .copyToPasteboard, UIActivity.ActivityType(rawValue: "net.whatsapp.WhatsApp.ShareExtension"), nil] {
            #expect(item.activityViewController(controller, itemForActivityType: target) as? String == "plain invitation")
            #expect(item.activityViewController(controller, dataTypeIdentifierForActivityType: target) == "public.plain-text")
        }
    }

}
