(import 'buffers)
(import 'python)


(defun message-wait(msg &optional wait)
  (wmessage msg)
  (let ((wait (or wait 1)))
    (sit-for wait)))

(defun buffer-switch-create(buffer)
  (switch-to-buffer (get-buffer-create (car buffer))))

(defun local:buffer-kill-noconfirm(buff)
  "kill-buffer-without-confirmation"
  (interactive)
  ;; (message-wait buff) >> 42
  (with-current-buffer buff
    (let ((buffer-modified-p nil))
      (kill-this-buffer))))

(defun buffer-kill-confirm(buffers &optional confirm)
  (if confirm
      ;; ask confirmation
      (mapc #'kill-buffer buffers)
    ;; do not ask
    (mapc #'local:buffer-kill-noconfirm buffers)))

(defun buffer-by-name-do(name func)
  (let ((buffers (filter-string name (mapcar #'buffer-name (buffer-list)))))
    (if buffers
	(funcall func buffers))))

(defun kill-process-pdb(&optional confirm)
  "kill all the pdb buffers"
  (interactive)
  (buffer-by-name-do "pdb" (lambda(buffers)
			     (buffer-kill-confirm buffers confirm))))

(defun kill-process-odoo()
  (local:concat-shell-run
   "lsof -i"
   "grep python"
   "grep LISTEN"
   "grep ':80'"
   "tr -s ' '"
   "cut -d ' ' -f2"
   "xargs -L 1 kill -9"))

(defun kill-odoo()
  (interactive)
  (kill-process-odoo)
  (kill-process-pdb))

(defun local:odoo-start(&optional start_script)
  (interactive)
  (setq start_script (completing-read "Choose an odoo: " odoo-paths))
  (setq command (concat "python2 -m pdb /root/.emacs.d/home/odoo.py "
			"--path " start_script " "
			"--config=/root/.emacs.d/home/odoo-server.conf"))
  ;; python2 -m pdb /root/.emacs.d/home/odoo.py --path /home/skyline/Development/enterprise/1 --config=/root/.emacs.d/home/odoo-server.conf
  ;; (message-wait command 10)
  (realgud:pdb command t))


(defun local:odoo-kill-start(&optional start_script)
  (interactive)
  (setq odoo-paths (odoo-find-start-script odoo-root))
  (kill-odoo)
  ;; don't know why but without delay does not work
  (sit-for 0.3)
  (local:odoo-start start_script))

(defun odoo-find-paths-cache(path cache)
  (if cache
      (shell-command-to-string (concat "cat " cache))
    (let ((paths (odoo-find-paths path)))
      (if paths
	  (local:concat-shell-run
	   (concat "echo " paths)
	   (concat "tee -a " cache))
	))))

(defun filter-empty-string(strings)
  ;; given a list of strings
  ;; retuns another list of not empty strings
  (-filter #'(lambda(x) (> (length x) 0)) strings))

(defun foreach-line-apply(func lines)
  (filter-empty-string
   (-flatten 
    (mapcar
     #'(lambda(path)
	 (split-string (funcall func path) "\n"))
     lines))))

(defun odoo-find-start-script(odoo-root)
  (foreach-line-apply
   #'(lambda(path) (odoo-find-paths-cache path odoo-paths-cache-file))
   odoo-root))

(defun odoo-find-paths(path save)
  (local:concat-shell-run
   (concat "find " path " -maxdepth 6 -type d -name addons")
   "xargs -L 1 dirname"
   (concat "while read l; "
	   "do ls $l/sql_db.py 1> /dev/null 2> /dev/null && echo $l; "
	   "done")
   "xargs -L 1 dirname"))

(setq
 pkgs '("/lib/python2.7/site-packages")
 odoo-root '("~/odoo")
 odoo-paths-cache-file "~/.emacs.d/home/odoopaths")

(global-set-key (kbd "C-c o") (local:wrapp 'local:odoo-kill-start '(t)))
