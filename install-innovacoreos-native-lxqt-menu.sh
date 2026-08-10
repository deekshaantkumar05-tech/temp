#!/bin/bash
set -Eeuo pipefail

# InnovacoreOS native LXQt Main Menu replacement.
# Targets the installed LXQt 2.1.x / Qt6 stack and replaces the
# built-in mainmenu plugin with a native InnovacoreOS implementation.

[[ $EUID -eq 0 ]] || { echo 'Run with sudo: sudo bash /mnt/data/install-innovacoreos-native-lxqt-menu.sh'; exit 1; }
command -v cmake >/dev/null || { echo 'cmake is required'; exit 1; }
command -v ninja >/dev/null || { echo 'ninja is required'; exit 1; }
command -v curl >/dev/null || { echo 'curl is required'; exit 1; }

P=2.1.4
W=/usr/local/src/innovacoreos-lxqt-panel
SRC="$W/lxqt-panel-$P"
BUILD="$W/build"
BACKUP="/root/innovacoreos-lxqt-panel-backup-$(date +%Y%m%d-%H%M%S)"
PLUGIN="$SRC/plugin-mainmenu"
SYSTEM_PANEL=/etc/xdg/lxqt/panel.conf
ICON=/usr/share/icons/Innovacore-menu-icon.png

mkdir -p "$W" "$BACKUP"

echo '============================================================'
echo ' INNOVACOREOS - NATIVE LXQT MENU CONVERSION'
echo '============================================================'
echo

echo '[1/8] Checking installed LXQt...'
lxqt-panel --version || true
qmake6 --version || true

echo

echo '[2/8] Preparing system-wide InnovacoreOS logo...'
if [[ ! -f "$ICON" ]]; then
  for f in /home/innovacore/temp/Innovacore-menu-icon.png \
           /home/innovacore/temp2/temp/Innovacore-menu-icon.png \
           /home/innovacore/temp2/temp/temp/Innovacore-menu-icon.png; do
    if [[ -f "$f" ]]; then install -Dm644 "$f" "$ICON"; break; fi
  done
fi
[[ -f "$ICON" ]] || echo 'WARNING: logo not found; fallback icon will be used.'

echo '[3/8] Backing up installed panel...'
cp -a /usr/bin/lxqt-panel "$BACKUP/" 2>/dev/null || true
cp -a /usr/lib/lxqt-panel "$BACKUP/" 2>/dev/null || true
cp -a /usr/share/lxqt/lxqt-panel "$BACKUP/" 2>/dev/null || true
cp -a "$SYSTEM_PANEL" "$BACKUP/panel.conf" 2>/dev/null || true

echo '[4/8] Obtaining clean lxqt-panel 2.1.4 source...'
if [[ ! -f "$SRC/CMakeLists.txt" ]]; then
  T="$W/lxqt-panel-$P.tar.gz"
  curl -fL "https://github.com/lxqt/lxqt-panel/archive/refs/tags/$P.tar.gz" -o "$T"
  rm -rf "$SRC"
  tar -xzf "$T" -C "$W"
fi
[[ -f "$SRC/CMakeLists.txt" ]] || { echo 'LXQt source extraction failed'; exit 1; }

# Preserve the pristine upstream plugin once.
[[ -f "$PLUGIN/lxqtmainmenu.cpp.innovacore-upstream" ]] || cp "$PLUGIN/lxqtmainmenu.cpp" "$PLUGIN/lxqtmainmenu.cpp.innovacore-upstream"
[[ -f "$PLUGIN/lxqtmainmenu.h.innovacore-upstream" ]] || cp "$PLUGIN/lxqtmainmenu.h" "$PLUGIN/lxqtmainmenu.h.innovacore-upstream"

cat > "$PLUGIN/lxqtmainmenu.h" <<'EOF'
#ifndef INNOVACORE_LXQT_MAINMENU_H
#define INNOVACORE_LXQT_MAINMENU_H
#include "../panel/ilxqtpanelplugin.h"
#include <QDialog>
#include <QLineEdit>
#include <QListWidget>
#include <QToolButton>
#include <QLabel>
#include <QVector>
class InnovacoreMenuWindow;
class LXQtMainMenu : public QObject, public ILXQtPanelPlugin {
    Q_OBJECT
public:
    explicit LXQtMainMenu(const ILXQtPanelPluginStartupInfo &info);
    ~LXQtMainMenu() override;
    QString themeId() const override { return QStringLiteral("InnovacoreMenu"); }
    Flags flags() const override { return NoFlags; }
    QWidget *widget() override { return &mButton; }
    bool isSeparate() const override { return true; }
protected:
    void settingsChanged() override;
private slots:
    void toggle();
    void category(int row);
    void search(const QString &text);
    void launch();
private:
    struct App { QString name, exec, icon, file; QStringList cats; };
    static QString cleanExec(QString s);
    static QIcon iconFor(const QString &s);
    static QStringList cats(const QString &s);
    void scan();
    void fillCategories();
    void fillApps();
    void showMenu();
    void hideMenu();
    QToolButton mButton;
    InnovacoreMenuWindow *mWindow = nullptr;
    QLineEdit *mSearch = nullptr;
    QListWidget *mCategories = nullptr;
    QListWidget *mApps = nullptr;
    QVector<App> mData;
    QStringList mCats;
    QString mCurrent = QStringLiteral("All Applications");
};
class LXQtMainMenuPluginLibrary : public QObject, public ILXQtPanelPluginLibrary {
    Q_OBJECT
    Q_INTERFACES(ILXQtPanelPluginLibrary)
public:
    ILXQtPanelPlugin *instance(const ILXQtPanelPluginStartupInfo &i) const override { return new LXQtMainMenu(i); }
};
#endif
EOF

cat > "$PLUGIN/lxqtmainmenu.cpp" <<'EOF'
#include "lxqtmainmenu.h"
#include <QApplication>
#include <QDir>
#include <QFileInfo>
#include <QHBoxLayout>
#include <QListWidgetItem>
#include <QProcess>
#include <QPushButton>
#include <QSettings>
#include <QStandardPaths>
#include <QStyle>
#include <QRegularExpression>
#include <algorithm>

class InnovacoreMenuWindow : public QDialog {
public:
    explicit InnovacoreMenuWindow(QWidget *p=nullptr):QDialog(p) {
        setWindowFlags(Qt::Popup|Qt::FramelessWindowHint);
        setAttribute(Qt::WA_TranslucentBackground);
        setObjectName("InnovacoreMenuWindow");
        setStyleSheet(R"(
QDialog#InnovacoreMenuWindow{background:#071923;border:1px solid #314c58;border-radius:14px;}
QLabel{color:#dce9ed;} QLabel#Title{color:#d4ed00;font-size:20px;font-weight:700;}
QLabel#Sub{color:#8fa8b2;font-size:11px;}
QListWidget{background:#0b202b;border:1px solid #203b47;border-radius:9px;outline:none;padding:6px;color:#dce9ed;}
QListWidget#Categories{background:#091b25;} QListWidget::item{padding:9px 10px;border-radius:7px;margin:2px;}
QListWidget::item:hover{background:#173744;} QListWidget::item:selected{background:#d4ed00;color:#071923;font-weight:700;}
QLineEdit{background:#0b202b;color:white;border:1px solid #3d5d69;border-radius:9px;padding:9px 12px;selection-background-color:#d4ed00;selection-color:#071923;}
QPushButton{background:#102633;color:#dce9ed;border:1px solid #314c58;border-radius:8px;padding:7px 12px;}
QPushButton:hover{background:#183744;border-color:#d4ed00;})
        ");
    }
};

QStringList LXQtMainMenu::cats(const QString &s){ QStringList r; for(auto x:s.split(';',Qt::SkipEmptyParts)){x=x.trimmed();if(!x.isEmpty())r<<x;} return r; }
QString LXQtMainMenu::cleanExec(QString s){ s.remove(QRegularExpression("%[fFuUdDnNickvm]")); return s.trimmed(); }
QIcon LXQtMainMenu::iconFor(const QString &s){
    if(s.isEmpty()) return QApplication::style()->standardIcon(QStyle::SP_DesktopIcon);
    if(QFileInfo::exists(s)) return QIcon(s);
    for(const QString &x:{QStringLiteral(".png"),QStringLiteral(".svg"),QStringLiteral(".xpm")}) if(QFileInfo::exists(s+x)) return QIcon(s+x);
    auto q=QIcon::fromTheme(s); return q.isNull()?QApplication::style()->standardIcon(QStyle::SP_DesktopIcon):q;
}
LXQtMainMenu::LXQtMainMenu(const ILXQtPanelPluginStartupInfo &i):QObject(),ILXQtPanelPlugin(i){
    mButton.setAutoRaise(true); mButton.setToolButtonStyle(Qt::ToolButtonIconOnly); mButton.setIconSize(QSize(30,30));
    mButton.setIcon(iconFor("/usr/share/icons/Innovacore-menu-icon.png")); mButton.setToolTip("InnovacoreOS Menu");
    mButton.setStyleSheet("QToolButton{border:none;background:transparent;padding:4px;border-radius:7px;}QToolButton:hover{background:rgba(212,237,0,35);}QToolButton:pressed{background:rgba(212,237,0,60);}");
    connect(&mButton,&QToolButton::clicked,this,&LXQtMainMenu::toggle);
    mWindow=new InnovacoreMenuWindow(); mWindow->setFixedSize(758,850);
    auto *root=new QVBoxLayout(mWindow); root->setContentsMargins(18,16,18,14); root->setSpacing(10);
    auto *head=new QHBoxLayout; auto *logo=new QLabel; logo->setFixedSize(54,54); logo->setScaledContents(true); logo->setPixmap(iconFor("/usr/share/icons/Innovacore-menu-icon.png").pixmap(48,48));
    auto *ht=new QVBoxLayout; auto *title=new QLabel("INNOVACOREOS"); title->setObjectName("Title"); auto *sub=new QLabel("System Application Menu"); sub->setObjectName("Sub"); ht->addWidget(title);ht->addWidget(sub);head->addWidget(logo);head->addLayout(ht);head->addStretch();root->addLayout(head);
    mSearch=new QLineEdit; mSearch->setPlaceholderText("Search applications..."); root->addWidget(mSearch);
    auto *body=new QHBoxLayout; body->setSpacing(10); mCategories=new QListWidget; mCategories->setObjectName("Categories");mCategories->setFixedWidth(210);mCategories->setIconSize(QSize(22,22));mApps=new QListWidget;mApps->setIconSize(QSize(28,28));body->addWidget(mCategories);body->addWidget(mApps,1);root->addLayout(body,1);
    auto *foot=new QHBoxLayout; auto *f=new QLabel("InnovacoreOS");f->setStyleSheet("color:#708b95;font-size:10px;");foot->addWidget(f);foot->addStretch();auto *close=new QPushButton("Close");close->setFixedWidth(75);foot->addWidget(close);root->addLayout(foot);
    connect(close,&QPushButton::clicked,this,&LXQtMainMenu::hideMenu); connect(mCategories,&QListWidget::currentRowChanged,this,&LXQtMainMenu::category);connect(mSearch,&QLineEdit::textChanged,this,&LXQtMainMenu::search);connect(mApps,&QListWidget::itemActivated,this,[this](QListWidgetItem*){launch();});
    scan();fillCategories();fillApps();
}
LXQtMainMenu::~LXQtMainMenu(){if(mWindow)mWindow->deleteLater();}
void LXQtMainMenu::settingsChanged(){fillApps();}
void LXQtMainMenu::scan(){
    mData.clear(); QStringList dirs; auto home=QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation); if(!home.isEmpty())dirs<<home;dirs<<"/usr/local/share/applications"<<"/usr/share/applications";QSet<QString>seen;
    for(const auto &d:dirs){QDir dir(d);for(const auto &fn:dir.entryList({"*.desktop"},QDir::Files,QDir::Name)){auto path=dir.absoluteFilePath(fn);if(seen.contains(path))continue;seen.insert(path);QSettings s(path,QSettings::IniFormat);s.beginGroup("Desktop Entry");if(s.value("Type").toString()!="Application"||s.value("Hidden",false).toBool()||s.value("NoDisplay",false).toBool())continue;auto only=cats(s.value("OnlyShowIn").toString());auto nots=cats(s.value("NotShowIn").toString());if(!only.isEmpty()&&!only.contains("LXQt"))continue;if(nots.contains("LXQt"))continue;App a;a.name=s.value("Name").toString();a.exec=cleanExec(s.value("Exec").toString());a.icon=s.value("Icon").toString();a.cats=cats(s.value("Categories").toString());a.file=path;if(!a.name.isEmpty()&&!a.exec.isEmpty())mData.push_back(a);}}
    std::sort(mData.begin(),mData.end(),[](const App&a,const App&b){return a.name.localeAwareCompare(b.name)<0;});
}
void LXQtMainMenu::fillCategories(){mCats={"All Applications","Internet","Multimedia","Graphics","Development","Office","Utilities","System","Terminal","Games","Education","Science","Security","Other"};mCategories->clear();for(auto&c:mCats)mCategories->addItem(c);if(mCategories->count())mCategories->setCurrentRow(0);}
void LXQtMainMenu::fillApps(){if(!mApps)return;mApps->clear();auto f=mSearch?mSearch->text().trimmed():QString();for(const auto&a:mData){if(!f.isEmpty()&&!a.name.contains(f,Qt::CaseInsensitive)&&!a.exec.contains(f,Qt::CaseInsensitive))continue;if(mCurrent!="All Applications"){bool ok=false;for(auto c:a.cats){if(c.compare(mCurrent,Qt::CaseInsensitive)==0)ok=true;if(mCurrent=="Utilities"&&c=="Utility")ok=true;if(mCurrent=="System"&&(c=="System"||c=="Settings"))ok=true;}if(!ok)continue;}auto*i=new QListWidgetItem(iconFor(a.icon),a.name);i->setData(Qt::UserRole,a.file);mApps->addItem(i);}}
void LXQtMainMenu::category(int row){if(row>=0&&row<mCats.size()){mCurrent=mCats[row];fillApps();}}
void LXQtMainMenu::search(const QString&){fillApps();}
void LXQtMainMenu::launch(){auto*i=mApps->currentItem();if(!i)return;auto file=i->data(Qt::UserRole).toString();QSettings s(file,QSettings::IniFormat);s.beginGroup("Desktop Entry");auto ex=cleanExec(s.value("Exec").toString());if(ex.isEmpty())return;bool term=s.value("Terminal",false).toBool();hideMenu();if(term)QProcess::startDetached("qterminal",{"-e","sh","-c",ex});else QProcess::startDetached("/bin/sh",{"-c",ex});}
void LXQtMainMenu::toggle(){if(mWindow->isVisible())hideMenu();else showMenu();}
void LXQtMainMenu::showMenu(){scan();fillApps();willShowWindow(mWindow);auto r=calculatePopupWindowPos(mWindow->size());mWindow->move(r.topLeft());mWindow->show();mWindow->raise();mSearch->setFocus();}
void LXQtMainMenu::hideMenu(){if(mWindow)mWindow->hide();}
EOF

cat > "$PLUGIN/resources/mainmenu.desktop.in" <<'EOF'
[Desktop Entry]
Type=Service
ServiceTypes=LXQtPanel/Plugin
Name=InnovacoreOS Menu
Comment=InnovacoreOS application menu
Icon=start-here-lxqt
#TRANSLATIONS_DIR=../translations
EOF

# Build only the features needed by the current InnovacoreOS panel.
rm -rf "$BUILD"; mkdir -p "$BUILD"; cd "$BUILD"
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
  -DCPULOAD_PLUGIN=No -DSENSORS_PLUGIN=No -DNETWORKMONITOR_PLUGIN=No \
  -DSYSSTAT_PLUGIN=No -DQEYES_PLUGIN=No -DBACKLIGHT_PLUGIN=No \
  -DUSE_MENU_CACHE=No "$SRC"
ninja -j"$(nproc)"
ninja install

# Native mainmenu is now built into lxqt-panel. Replace QuickLaunch in the
# system default panel and migrate existing users. Keep backups.
mkdir -p /etc/xdg/lxqt /etc/skel/.config/lxqt
cp -a "$SYSTEM_PANEL" "$BACKUP/panel.conf.before-native-menu" 2>/dev/null || true
cat > "$SYSTEM_PANEL" <<'EOF'
[General]
__userfile__=true

[mainmenu]
alignment=Left
type=mainmenu

[desktopswitch]
alignment=Left
type=desktopswitch

[mount]
alignment=Right
type=mount

[panel1]
alignment=-1
animation-duration=0
background-color=@Variant(\0\0\0\x43\0\xff\xff\0\0\0\0\0\0\0\0)
background-image=
desktop=0
font-color=@Variant(\0\0\0\x43\0\xff\xff\0\0\0\0\0\0\0\0)
hidable=false
hide-on-overlap=false
iconSize=27
lineCount=1
lockPanel=false
opacity=100
panelSize=45
position=Bottom
reserve-space=true
show-delay=0
visible-margin=true
width=100
width-percent=true

[showdesktop]
alignment=Right
type=showdesktop

[statusnotifier]
alignment=Right
type=statusnotifier

[taskbar]
alignment=Left
type=taskbar

[tray]
alignment=Right
type=tray

[volume]
alignment=Right
type=volume

[worldclock]
alignment=Right
type=worldclock
EOF
install -Dm644 "$SYSTEM_PANEL" /etc/skel/.config/lxqt/panel.conf

mkdir -p /etc/xdg/innovacoreos
cat > /etc/xdg/innovacoreos/menu.conf <<'EOF'
[Menu]
width=758
height=850
splitPercent=50
splitterLeft=402
splitterRight=332
logo=/usr/share/icons/Innovacore-menu-icon.png
EOF

# Existing users: replace their panel config so the old per-user QuickLaunch
# cannot override the system default. Backup each one first.
mkdir -p "$BACKUP/users"
for h in /home/*; do
  [[ -d "$h" ]] || continue
  u=${h##*/}; [[ "$u" == lost+found ]] && continue
  p="$h/.config/lxqt/panel.conf"
  if [[ -f "$p" ]]; then
    mkdir -p "$BACKUP/users/$u"
    cp -a "$p" "$BACKUP/users/$u/panel.conf"
    install -Dm644 "$SYSTEM_PANEL" "$p"
    chown "$u:$u" "$p" 2>/dev/null || true
  fi
done

# Do not remove the old standalone executable yet; it is deliberately kept
# as rollback/reference until the native plugin has been tested.

echo
echo '============================================================'
echo ' NATIVE INNOVACOREOS MENU INSTALLED'
echo '============================================================'
echo
 echo "Backup: $BACKUP"
echo "Native implementation: built into lxqt-panel as mainmenu"
echo "System panel: $SYSTEM_PANEL"
echo "Future-user panel: /etc/skel/.config/lxqt/panel.conf"
echo
 echo 'Restart the panel now:'
echo '  lxqt-panel --replace >/tmp/innovacoreos-panel.log 2>&1 &'
echo
 echo 'If the panel is already running, logging out/in is the safest test.'
echo 'Do NOT delete the old InnovacoreOS menu executable yet.'
echo
