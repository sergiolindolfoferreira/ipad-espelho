// iPad Espelho — mostra o ecrã de um iPad/iPhone ligado por cabo numa janela do Mac.
// Usa o mesmo mecanismo do QuickTime ("Nova gravação de filme" → iPad como câmara).

import Cocoa
import AVFoundation
import CoreMediaIO

// Permite que os ecrãs de dispositivos iOS ligados por USB apareçam como câmaras.
func permitirDispositivosDeEcra() {
    var prop = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    var allow: UInt32 = 1
    CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil,
                              UInt32(MemoryLayout<UInt32>.size), &allow)
}

final class EcraView: NSView {
    let preview = AVCaptureVideoPreviewLayer()
    let aviso = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        preview.videoGravity = .resizeAspect
        preview.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(preview)

        aviso.textColor = .white
        aviso.font = .systemFont(ofSize: 17, weight: .medium)
        aviso.alignment = .center
        aviso.maximumNumberOfLines = 0
        aviso.translatesAutoresizingMaskIntoConstraints = false
        addSubview(aviso)
        NSLayoutConstraint.activate([
            aviso.centerXAnchor.constraint(equalTo: centerXAnchor),
            aviso.centerYAnchor.constraint(equalTo: centerYAnchor),
            aviso.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -40),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        preview.frame = bounds
        CATransaction.commit()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var janela: NSWindow!
    let vista = EcraView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
    let sessao = AVCaptureSession()
    var dispositivoAtual: AVCaptureDevice?
    var menuDispositivos = NSMenu(title: "Dispositivo")
    var itemSempreNoTopo: NSMenuItem!
    var observadorFormato: NSObjectProtocol?

    func applicationDidFinishLaunching(_ n: Notification) {
        construirMenu()
        janela = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        janela.title = "iPad Espelho"
        janela.contentView = vista
        janela.delegate = self
        janela.setFrameAutosaveName("JanelaiPadEspelho")
        janela.center()
        janela.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        vista.preview.session = sessao
        mostrarAviso("A procurar o iPad…")

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(dispositivosMudaram), name: AVCaptureDevice.wasConnectedNotification, object: nil)
        nc.addObserver(self, selector: #selector(dispositivosMudaram), name: AVCaptureDevice.wasDisconnectedNotification, object: nil)

        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async {
                if ok {
                    permitirDispositivosDeEcra()
                    // O iPad pode demorar uns segundos a aparecer depois de ativar a propriedade.
                    self.dispositivosMudaram()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.dispositivosMudaram() }
                } else {
                    self.mostrarAviso("Sem acesso à câmara.\nAtiva o iPad Espelho em Definições do Sistema → Privacidade e segurança → Câmara.")
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }

    // MARK: Dispositivos

    func dispositivosiOS() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: .muxed, position: .unspecified).devices
    }

    @objc func dispositivosMudaram() {
        let lista = dispositivosiOS()
        reconstruirMenuDispositivos(lista)
        if let atual = dispositivoAtual, lista.contains(atual) { return }
        if let primeiro = lista.first { ligar(primeiro) } else { desligar() }
    }

    func ligar(_ d: AVCaptureDevice) {
        sessao.beginConfiguration()
        sessao.inputs.forEach { sessao.removeInput($0) }
        do {
            let entrada = try AVCaptureDeviceInput(device: d)
            if sessao.canAddInput(entrada) { sessao.addInput(entrada) }
        } catch {
            sessao.commitConfiguration()
            mostrarAviso("Não consegui abrir \(d.localizedName):\n\(error.localizedDescription)")
            return
        }
        sessao.commitConfiguration()
        dispositivoAtual = d
        janela.title = d.localizedName
        mostrarAviso(nil)
        DispatchQueue.global(qos: .userInitiated).async { self.sessao.startRunning() }

        // Ajusta a janela à proporção do ecrã (e quando o iPad roda).
        if let o = observadorFormato { NotificationCenter.default.removeObserver(o) }
        observadorFormato = NotificationCenter.default.addObserver(
            forName: AVCaptureInput.Port.formatDescriptionDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.ajustarProporcao()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.ajustarProporcao() }
        reconstruirMenuDispositivos(dispositivosiOS())
    }

    func desligar() {
        if sessao.isRunning { sessao.stopRunning() }
        sessao.inputs.forEach { sessao.removeInput($0) }
        dispositivoAtual = nil
        janela.title = "iPad Espelho"
        janela.contentAspectRatio = .zero
        mostrarAviso("Liga o iPad ao Mac por cabo USB‑C,\ndesbloqueia-o e toca em «Confiar» se te for pedido.")
    }

    func ajustarProporcao() {
        guard let d = dispositivoAtual else { return }
        let dim = CMVideoFormatDescriptionGetDimensions(d.activeFormat.formatDescription)
        guard dim.width > 0, dim.height > 0 else { return }
        let proporcao = NSSize(width: CGFloat(dim.width), height: CGFloat(dim.height))
        janela.contentAspectRatio = proporcao

        // Mantém a área e o centro, mudando só a forma.
        var frame = janela.frame
        let conteudo = janela.contentRect(forFrameRect: frame)
        let area = conteudo.width * conteudo.height
        let r = proporcao.width / proporcao.height
        var novaAltura = (area / r).squareRoot()
        var novaLargura = novaAltura * r
        if let ecra = janela.screen?.visibleFrame {
            let escala = min(1, (ecra.height - 40) / novaAltura, (ecra.width - 40) / novaLargura)
            novaAltura *= escala; novaLargura *= escala
        }
        let novoConteudo = NSRect(x: conteudo.midX - novaLargura / 2, y: conteudo.midY - novaAltura / 2,
                                  width: novaLargura, height: novaAltura)
        frame = janela.frameRect(forContentRect: novoConteudo)
        janela.setFrame(frame, display: true, animate: true)
    }

    func mostrarAviso(_ texto: String?) {
        vista.aviso.stringValue = texto ?? ""
        vista.aviso.isHidden = texto == nil
    }

    // MARK: Menus

    func construirMenu() {
        let barra = NSMenu()

        let appItem = NSMenuItem(); barra.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Acerca do iPad Espelho", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Ocultar iPad Espelho", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Sair do iPad Espelho", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let visItem = NSMenuItem(); barra.addItem(visItem)
        let visMenu = NSMenu(title: "Visualização")
        itemSempreNoTopo = NSMenuItem(title: "Sempre no topo", action: #selector(alternarTopo), keyEquivalent: "t")
        visMenu.addItem(itemSempreNoTopo)
        visMenu.addItem(withTitle: "Tamanho real (1:1)", action: #selector(tamanhoReal), keyEquivalent: "1")
        visMenu.addItem(withTitle: "Ecrã inteiro", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        visItem.submenu = visMenu

        let dispItem = NSMenuItem(); barra.addItem(dispItem)
        dispItem.submenu = menuDispositivos

        let janItem = NSMenuItem(); barra.addItem(janItem)
        let janMenu = NSMenu(title: "Janela")
        janMenu.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        janMenu.addItem(withTitle: "Fechar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        janItem.submenu = janMenu
        NSApp.windowsMenu = janMenu

        NSApp.mainMenu = barra
        reconstruirMenuDispositivos([])
    }

    func reconstruirMenuDispositivos(_ lista: [AVCaptureDevice]) {
        menuDispositivos.removeAllItems()
        if lista.isEmpty {
            let i = NSMenuItem(title: "Nenhum iPad ligado", action: nil, keyEquivalent: ""); i.isEnabled = false
            menuDispositivos.addItem(i)
        }
        for d in lista {
            let i = NSMenuItem(title: d.localizedName, action: #selector(escolherDispositivo(_:)), keyEquivalent: "")
            i.representedObject = d.uniqueID
            i.state = d == dispositivoAtual ? .on : .off
            i.target = self
            menuDispositivos.addItem(i)
        }
        menuDispositivos.addItem(.separator())
        let r = NSMenuItem(title: "Procurar de novo", action: #selector(dispositivosMudaram), keyEquivalent: "r")
        r.target = self
        menuDispositivos.addItem(r)
    }

    @objc func escolherDispositivo(_ s: NSMenuItem) {
        guard let id = s.representedObject as? String,
              let d = dispositivosiOS().first(where: { $0.uniqueID == id }) else { return }
        ligar(d)
    }

    @objc func alternarTopo() {
        janela.level = janela.level == .floating ? .normal : .floating
        itemSempreNoTopo.state = janela.level == .floating ? .on : .off
    }

    @objc func tamanhoReal() {
        guard let d = dispositivoAtual else { return }
        let dim = CMVideoFormatDescriptionGetDimensions(d.activeFormat.formatDescription)
        let escala = janela.backingScaleFactor
        var c = janela.contentRect(forFrameRect: janela.frame)
        c.size = NSSize(width: CGFloat(dim.width) / escala, height: CGFloat(dim.height) / escala)
        janela.setFrame(janela.frameRect(forContentRect: c), display: true, animate: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
