;;; econky.el --- Econky Dashboard Pro -*- lexical-binding: t; -*-
;; Copyright (C) 2026 Jeremias-A-Queiroz

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; Author: Jeremias-A-Queiroz
;; URL: github.com:Jeremias-A-Queiroz/econky.git
;; Version: 0.0.1
;; Package-Requires: ((symon "1.2.1"))

;;; Commentary:

;; Econky is a side-buffer system monitor inspired by Conky.
;; It uses `symon` as a back-end for system metrics but provides
;; a high-fidelity dashboard for IP addresses (v4/v6), Battery,
;; and Network traffic.

;; Usage:
;;
;;   (require 'econky)
;;
;; To start the monitor:
;;   M-x econky-start
;;
;; To stop the monitor:
;;   M-x econky-stop

;;; Change Log:

;; 0.0.1 (2026-02-18)
;; - Initial release as independent project.
;; - Integrated IPv6/IPv4 multi-interface table.
;; - Added smart battery detection.
;; - Precise column alignment for network interfaces.

;;; Code:

(require 'symon)
(require 'battery)

(defvar econky-timer nil)
(defvar symon-linux--last-cpu-ticks nil)
(defvar symon-linux--last-net-ticks nil)

;; --- Funções de Estética ---

(defun econky--bar (percent width)
  "Cria uma barra de progresso ASCII lidando com valores nulos."
  (let* ((safe-percent (if (numberp percent) (max 0 (min 100 percent)) 0))
         (filled-width (floor (* (/ (float safe-percent) 100.0) width)))
         (empty-width (- width filled-width)))
    (concat "[" 
            (propertize (make-string filled-width ?#) 'face 'success)
            (propertize (make-string empty-width ?-) 'face 'shadow)
            "]")))

;; --- Monitores de Sistema ---

(defun econky--get-ip ()
  "Lista todos os IPs do Tesla com alinhamento rigoroso por coluna."
  (let* ((interfaces (network-interface-list))
         (v6-list nil)
         (v4-list nil))
    (dolist (iface interfaces)
      (let ((name (car iface))
            (addr (cdr iface)))
        (unless (or (string= name "lo") (string-prefix-p "docker" name))
          (cond
           ;; IPv6 Global (Vetor de 9 posições)
           ((and (= (length addr) 9) (not (= (aref addr 0) 65152)))
            (push (format "%-10s %s" 
                          (concat name ":") 
                          (format "%x:%x:%x:%x:%x:%x:%x:%x" 
                                  (aref addr 0) (aref addr 1) (aref addr 2) (aref addr 3) 
                                  (aref addr 4) (aref addr 5) (aref addr 6) (aref addr 7)))
                  v6-list))
           ;; IPv4 (Vetor de 5 posições)
           ((= (length addr) 5)
            (push (format "%-10s %d.%d.%d.%d" 
                          (concat name ":") 
                          (aref addr 0) (aref addr 1) (aref addr 2) (aref addr 3))
                  v4-list))))))
    ;; Junta e remove duplicatas
    (concat 
     (when v6-list (concat (mapconcat 'identity (delete-dups (reverse v6-list)) "\n ") "\n "))
     (when v4-list (mapconcat 'identity (delete-dups (reverse v4-list)) "\n ")))))

(defun econky--fetch-battery ()
  "Retorna uma lista com (porcentagem . status) da bateria do notebook."
  (condition-case nil
      (let ((battery-data (battery-linux-sysfs)))
        (cons (string-to-number (cdr (assoc ?p battery-data)))
              (cdr (assoc ?L battery-data))))
    (error (cons 0 "N/A"))))

(defun econky--fetch-net ()
  "Retorna download/upload formatado corretamente."
  (let ((net (symon-linux-network-monitor-fetch-logic)))
    (if (and net (consp net))
        (format "D: %4d kb/s U: %4d kb/s" (or (car net) 0) (or (cdr net) 0))
      "Calculando rede...")))

;; --- O Renderizador Principal ---

(defun econky-render ()
  "O coração visual do Econky, com suporte a múltiplas interfaces e bateria."
  (let ((buf (get-buffer-create "*econky*")))
    (when (get-buffer-window buf t)
      (with-current-buffer buf
        (let* ((inhibit-read-only t)
               (cpu (or (symon-linux-cpu-monitor-fetch-logic) 0))
               (mem (or (symon-linux-memory-monitor-fetch-logic) 0))
               (bat-info (econky--fetch-battery))
               (bat-pct (car bat-info))
               (bat-status (cdr bat-info))
               (net-info (econky--fetch-net)))
          
          (erase-buffer)
          (insert (propertize " HOST: " 'face 'bold) (system-name) "\n")
          (insert (propertize " IP:   " 'face 'bold) "\n ")
          (insert (econky--get-ip) "\n")
          (insert (propertize (make-string 25 ?━) 'face 'shadow) "\n\n")

          ;; Recursos Principais
          (insert (propertize " CPU " 'face 'bold) 
                  (format "%3d%% " cpu) (econky--bar cpu 12) "\n")
          (insert (propertize " MEM " 'face 'bold) 
                  (format "%3d%% " mem) (econky--bar mem 12) "\n")
          
          ;; Monitor de Bateria
	  (unless (string= (cdr bat-info) "N/A")
            (insert (propertize " BAT " 'face 'bold) 
                    (format "%3d%% " bat-pct) (econky--bar bat-pct 12)
                    (propertize (format " (%s)" bat-status) 'face 'italic) "\n"))

	  (insert "\n")

          (insert (propertize " NETWORK\n " 'face 'bold) net-info "\n")
          
          (insert "\n" (propertize (make-string 25 ?━) 'face 'shadow) "\n")
          (insert (propertize " UP: " 'face 'bold) (emacs-uptime) "\n")
          (insert (propertize (format " AT: %s" (format-time-string "%H:%M:%S")) 
                              'face 'italic 'foreground "gray50"))
          
          (read-only-mode 1))))))

;; --- Controle do Timer ---

(defun econky-start ()
  "Inicia o dashboard."
  (interactive)
  (econky-stop)
  (setq econky-timer (run-with-timer 0 2 #'econky-render)))

(defun econky-stop ()
  "Para o dashboard."
  (interactive)
  (when econky-timer
    (cancel-timer econky-timer)
    (setq econky-timer nil)))

;; --- Lógica de Rede Symon ---

(defun symon-linux-network-monitor-fetch-logic ()
  "Lógica de rede baseada no Symon, extraindo dados de /proc/net/dev."
  (let ((stats (delq nil (symon-linux--read-lines "/proc/net/dev" 
                 (lambda (str) 
                   (when (string-match ":\\s-*\\(.*\\)" str)
                     (mapcar 'read (split-string (match-string 1 str) nil t))))
                 '("eth" "wlan" "enp" "wlp" "lo")))))
    (if (null stats)
        nil
      (let ((in (apply '+ (mapcar (lambda (x) (if (numberp (nth 0 x)) (nth 0 x) 0)) stats)))
            (out (apply '+ (mapcar (lambda (x) (if (numberp (nth 8 x)) (nth 8 x) 0)) stats))))
        (if symon-linux--last-net-ticks
            (let ((in-diff (/ (- in (car symon-linux--last-net-ticks)) 1024))
                  (out-diff (/ (- out (cdr symon-linux--last-net-ticks)) 1024)))
              (setq symon-linux--last-net-ticks (cons in out))
              (cons (max 0 in-diff) (max 0 out-diff)))
          (setq symon-linux--last-net-ticks (cons in out))
          nil)))))

(provide 'econky)
