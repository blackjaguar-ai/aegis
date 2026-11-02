import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_Acento: acento.currentIndex
    QQC2.ComboBox { id: acento; Kirigami.FormData.label: "Acento:"; model: ["Cian", "Ámbar", "Carmesí", "Verde"] }
}
