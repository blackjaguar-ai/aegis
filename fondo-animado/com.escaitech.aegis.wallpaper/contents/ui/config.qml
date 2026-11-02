import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout
    property alias formLayout: root
    property alias cfg_Animar: animar.checked
    property alias cfg_Acento: acento.currentIndex
    QQC2.CheckBox { id: animar; Kirigami.FormData.label: "Animación:"; text: "Animar la escena" }
    QQC2.ComboBox { id: acento; Kirigami.FormData.label: "Acento:"; model: ["Cian", "Ámbar", "Carmesí", "Verde"] }
}
