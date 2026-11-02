// AEGIS - barra superior: inicio | apps | (reloj centrado) | bandeja. __LANZADORES__ se sustituye desde aplicar.sh.
var p = panels().length ? panels()[0] : new Panel("org.kde.panel");
p.location = "top";
p.height = 34;
p.lengthMode = "fill";
p.alignment = "center";
p.floating = false;
p.opacity = "translucent";
p.hiding = "none";
var ids = p.widgetIds;
for (var i = 0; i < ids.length; i++) { p.widgetById(ids[i]).remove(); }

p.addWidget("org.kde.plasma.kickoff");
var t = p.addWidget("org.kde.plasma.icontasks");
t.currentConfigGroup = ["General"];
t.writeConfig("launchers", "__LANZADORES__");
t.writeConfig("groupingStrategy", 0);

p.addWidget("org.kde.plasma.panelspacer");
var c = p.addWidget("org.kde.plasma.digitalclock");
c.currentConfigGroup = ["Appearance"];
c.writeConfig("showDate", true);
c.writeConfig("dateFormat", "custom");
c.writeConfig("customDateFormat", "ddd d MMM");
c.writeConfig("dateDisplayFormat", "BesideTime");
c.writeConfig("use24hFormat", 2);
c.writeConfig("fontFamily", "Rajdhani");
c.writeConfig("boldText", true);
p.addWidget("org.kde.plasma.panelspacer");

var s = p.addWidget("org.kde.plasma.systemtray");
s.currentConfigGroup = ["General"];
var visibles = "org.kde.plasma.networkmanagement,org.kde.plasma.volume,org.kde.plasma.battery,org.kde.plasma.bluetooth";
var ocultos = "org.kde.plasma.notifications,org.kde.plasma.clipboard,org.kde.plasma.devicenotifier,org.kde.plasma.brightness,org.kde.kdeconnect,org.kde.plasma.mediacontroller,org.kde.kscreen,org.kde.plasma.keyboardlayout";
s.writeConfig("extraItems", visibles + "," + ocultos);
s.writeConfig("shownItems", visibles);
s.writeConfig("hiddenItems", ocultos);
print("AEGIS: barra superior lista");
