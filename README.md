# Econky: The Linux Power-User Dashboard for Emacs
 **Econky** (Emacs-Conky) is a lightweight, side-buffer system monitor for GNU Emacs, heavily inspired by the classic Linux Conky. It provides a real-time, high-fidelity overview of your system's health, networking, and power status, specifically optimized for multi-interface laptop setups.

## Features

* **Smart Networking Table**: Lists all IPv4 and Global IPv6 addresses with precise column alignment, ignoring local `fe80` addresses.
* **Intelligent Battery Monitor**: Automatically detects battery presence. Displays a progress bar and status (AC/Discharging) or hides itself on desktops/servers.
* **Resource Visualization**: Clean ASCII bars for CPU and Memory usage with "shielded" logic to handle null values.
* **Traffic Monitoring**: Real-time Download and Upload speeds (in kb/s) using `symon` logic adapted for modern interface names.
* **Modular Architecture**: Built as an independent project with `symon` as a dependency, allowing for a clean versioning cycle.

## Installation

### Prerequisites

Econky depends on the `symon` package for its core metric collection.

1. Ensure you have `symon` installed: `M-x package-install RET symon RET`.
2. Clone this repository into your load path:
   ```bash
   git clone [https://github.com/seu-usuario/econky.git](https://github.com/seu-usuario/econky.git) ~/.emacs.d/lisp/econky
   ```

### Basic Configuration

Add the following to your `init.el`:

```elisp
(add-to-list 'load-path "~/.emacs.d/lisp/econky")
(require 'econky)

;; The dashboard is started manually or via hooks
;; M-x econky-start
```

## Usage

* `M-x econky-start`: Initializes the `*econky*` buffer and starts the 2-second refresh timer.
* `M-x econky-stop`: Stops the refresh timer.

---

## Pro Setup: The 80/20 Layout (emacsclient)

A common use case for Econky is to have it automatically appear when opening a new Emacs frame via `emacsclient -c`, creating a dedicated system monitoring area.

Add the following hook to your `init.el`. It ensures that when a new frame is created, the window is split: **80%** for your work (`*scratch*` or current buffer) and **20%** pinned on the right for **Econky**.

```elisp
(defun my/setup-econky-frame (frame)
  "Configura o layout 80/20 ao abrir um novo frame via emacsclient."
  (with-selected-frame frame
    (let ((econky-buffer (get-buffer-create "*econky*")))
      ;; 1. Inicia o timer do Econky caso não esteja rodando
      (econky-start)
      
      ;; 2. Divide a janela: 80% esquerda, 20% direita
      (let ((window-side (split-window-right (- (window-total-width) 
                                                (/ (window-total-width) 5)))))
        ;; 3. Garante o foco no scratch à esquerda
        (switch-to-buffer "*scratch*")
        
        ;; 4. Exibe o Econky na janela da direita
        (set-window-buffer window-side econky-buffer)
        
        ;; 5. Torna a janela 'dedicada' para evitar que outros 
       ;; buffers ocupem o lugar do Econky
        (set-window-dedicated-p window-side t)))))

;; Ativa o layout apenas para novos frames criados (ex: emacsclient -c)
(add-hook 'after-make-frame-functions #'my/setup-econky-frame)
```

## License

This project is licensed under the **GNU General Public License v3.0**.

---
 *Created with focus on performance and aesthetics for the emacs environment.*
