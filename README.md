# ctags.l-for-xyzzy
an extension to use ctags.exe with xyzzy

xyzzy で Exuberant ctags の Win32 日本語対応版を使えるようにする拡張。

インストール
----------
ctags.l を site-lisp に入れてバイトコンパイル。 上の日本語対応版 ctags をもらってくる。etc に ctags.exe を入れた場合、 .xyzzy に次のように書く。

```
(load-library "ctags")
; ctags.exe へのパス
(setf *ctags-command-path* (merge-pathnames "etc/ctags.exe" (si:system-root)));
; ctags.exe へのその他のオプション
;(setf *ctags-command-option* "")
; キーバインド
(global-set-key #\M-. 'ctags-jump-tag)
(global-set-key #\M-\, 'ctags-back-tag-jump)
(global-set-key #\M-/ 'ctags-make-tags-file-recursive)
(global-set-key #\M-? 'ctags-select-stack)
```

キーバインドは好みで変更してよい。

使い方 
----------

* ctags-make-tags-file-recursive でソースツリーの起点となるフォルダで tags ファイル作る
* tags ファイルを作ったバッファのローカル変数として tags ファイルのマッピングを持ってる
* ctags-jump-tag でカーソル下の識別子でタグジャンプし、移動の履歴をスタックする
* ctags-back-tag-jump でスタックを逆向きに戻ってくる別のファイルに移った場合、マッピングを引き継ぐのでそのままタグジャンプできるマッピングがないバッファでタグジャンプした場合、使用する tags のありかを聞いて来る適切なフォルダの場所を与えればそこからマッピングを取り出し続行できる

歴史とたわごと
----------
* いつ作ったのかもうよく覚えてないなぁ
* 2007/12/02 速くなるか分からんが非表示バッファベースに切り替えてみる
** xzzzy がバッファを読み込む程度には読み込みが速くなることを期待
** その分検索ベースでタグのマッチするからそっちが遅くなるのかもなぁ
** テキストベースの ctags をこれ以上速くする方法おせーて
* 2007/12/08 NANRI さんの指摘を受けて / 入りの行への正規表現を修正ありがとー
* 2016/03 元公開場所だった fun.sci.fukuoka-u.ac.jp の閉鎖を受けて、たわごとを README.md に移動
