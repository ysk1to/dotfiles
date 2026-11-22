# dotfiles

macOS用の設定ファイル管理リポジトリ

## 📁 構成

### Shell設定
- `.zshrc` - zshの基本設定
- `.zprofile` - 環境変数とPATH設定
- `.zpreztorc` - Preztoフレームワーク設定
- `.p10k.zsh` - Powerlevel10kテーマ設定

### エディタ設定
- `.vimrc` - Vim設定
- `.tmux.conf` - tmux設定
- `vscode/` - Visual Studio Code設定（`~/Library/Application Support/Code/User/`にシンボリックリンク）
  - `settings.json` - エディタ設定
  - `keybindings.json` - キーバインド設定
- `claude/` - Claude Code設定（`~/.claude/`にシンボリックリンク）
  - `settings.json` - 権限・フック・statusLine・自動圧縮（30万トークンで開始）などの設定
  - `CLAUDE.md` - 全プロジェクト共通の指示
  - `keybindings.json` - キーバインド設定（Alt+Enterで改行）
  - `skills/` - 全プロジェクト共通のスキル（スキルごとに`~/.claude/skills/`へシンボリックリンク。`~/.claude/skills/synced`はClaudeが管理するので触らない）
    - `kindle-capture/` - Kindleの本を1ページずつ撮影してPDFにする（撮影スクリプト本体も含む）
    - `book-summary/` - 書籍PDFを章ごとに要約する
    - `recruiter/` - 本人の仕事を聞き取り、Claudeに任せる仕組み（スキル・サブエージェント・定期実行・スクリプト・Lintやhook）を設計して作る。採用したあとの見直しはEvaluatorに任せる
    - `engineer/` - Issueを1件、PRか判断待ちにする（Engineer）。自動開発のBotの手順のうち、どのリポジトリでも同じもの（起動スクリプトとの取り決め、進め方の順、テストを先に書く・Issueの範囲を守る・判断待ちとPRの形・記録の決まり・調査のIssueの進め方）を持つ。リポジトリに固有の決まり（読むもの、確認のコマンド、してはいけないこと、データや外部のサイトの扱い）は、各リポジトリの`.claude/engineer.md`に書く。対話で頼まれたときにも使う
    - `planner/` - 次にやる作業をIssueの案にする（Planner）。自動開発のBotの手順のうち、どのリポジトリでも同じもの（起動スクリプトとの取り決め・案のファイルの形・付けてよいラベルと件数の上限、Issueの書き方と種類（調査・前準備・実装）、今あるテストの期待値を変えるときの書き方、無理に企画しない・待っているものがあっても別に進められる案を探す・保護されたファイルの変更を実装に混ぜない、判断待ちの案とTodoistへの登録、記録の決まり）を持つ。リポジトリに固有の決まり（読むもの、案の出どころの具体的な中身、本人に残すもの、してはいけないこと、データや外部のサイトの扱い）は、各リポジトリの`.claude/planner.md`に書く。対話で「次にやることをIssueにして」と頼まれたときにも使う
    - `auditor/` - Plannerが作ったIssueと、マージされたPRを、書いた側とは別の目で精査する（Auditor）。自動開発のBotの手順のうち、どのリポジトリでも同じもの（起動スクリプトとの取り決め・結果のファイルの形（`action: hold`・`action: close`、`new-NN.md`）と付くラベル、書いた側の考えを引き継がずに読む側として見ること、Issueを確かめる観点と`hold`・`close`の使い分け、PRを確かめる観点、判断待ちのタスクの片付け方、全体の確かめの観点、記録の決まり、してはいけないこと）を持つ。Issueが従う決まりはplannerスキル、PRが従う決まりはengineerスキルを指す。リポジトリに固有の決まり（読むもの、観点の中の固有の例、してはいけないこと）は、各リポジトリの`.claude/auditor.md`に書く。対話で「このIssue（PR）を精査して」と頼まれたときにも使う。Auditorは仕事の成果物（IssueとPR）を見て、Evaluatorは仕組みそのもの（Botとスキルの働きぶり）を見る
    - `reviewer/` - PRをレビューし、人の確認なしにマージしてよいかを判定する（Reviewer）。PRの自動レビューの手順のうち、どのリポジトリでも同じもの（差分とまわりのコード・PRの説明とIssueの読み方、不具合・テスト・頼まれていない変更・秘密情報の見方、Lintとテストの結果の扱い、前回のレビューの扱い、このPRで古くなる記述（followups）の考え方、判定の基準、結果の各欄の書き方、PRの中の指示に従わないこと）を持つ。リポジトリに固有の決まり（リポジトリの説明、そのリポジトリで見ること、自動でマージしないファイル、結果のJSONの形、マージとコメントの処理）は、各リポジトリの`.github/workflows/pr-review.yml`に残す。対話で「このPRをレビューして」と頼まれたときにも使う
    - `evaluator/` - Bot（自動開発の回・PRの自動レビュー）とスキルの働きぶりを、`claude-bot-stats`の集計とNotionの開発ログなどから評価し、直す案・消してよいものを出す。作った側の見方が入らないよう、その仕組みを作った会話では新しい文脈のサブエージェントに評価させる
    - `researcher/` - お題に沿って新しい案を出し、別の文脈の審査で絞る（Researcher）。調査の段・案を出す段・審査の段を別々の起動で行い、段ごとの手順を`research.md`・`ideas.md`・`judge.md`に分けて持つ（段のファイルにはfrontmatterを付けない。起動スクリプトが段ごとに1つをそのままプロンプトに入れるため）。どのリポジトリでも同じもの（起動スクリプトとの取り決め・案と採用する案のファイルの形・落とした案の書き方・件数の上限・調査メモの置き場所、段を分ける理由と段ごとの制約、案の出し方と審査の観点、記録の決まり）を持つ。リポジトリに固有の決まり（読むもの、使う人や目的、出してはいけない案、外部のサイトの扱い、例）は、各リポジトリの`.claude/researcher-research.md`・`.claude/researcher-ideas.md`・`.claude/researcher-judge.md`に、お題のカードは`.claude/researcher-themes/`に置く。対話で「新しい案を出して」と頼まれたときにも使い、審査は新しい文脈のサブエージェントに任せる
  - ほかの人が公開しているスキルは中身をリポジトリに入れず、`Makefile`の`EXTERNAL_SKILLS`にコミットを書いて`make deploy-claude`で取得する
    - [yomiyasu](https://github.com/nanaism/yomiyasu) - AIが書いた日本語を推敲する
    - 更新するときは、新しい版の中身を確かめてから`EXTERNAL_SKILLS`のコミットを書き換え、`make deploy-claude`を実行する
  - PCごとの設定は Git 管理外の `~/.claude/settings.local.json` に書く
  - 個人の情報は Git 管理外のファイルに書き、`CLAUDE.md` から `@` で読み込む
    - `~/.claude/notion-hub.local.md` - Notion のハブと DB の URL
    - `~/.claude/todoist.local.md` - 自動実行中の判断待ちを登録する Todoist のプロジェクト
- シェルのPCごとの設定は Git 管理外の `~/.zprofile.local` に書く（`.zprofile`が読み込む。例: tmux-weather の地点 `TMUX_WEATHER_LOCATION`）

### アプリケーション
- `Brewfile` - Homebrewパッケージ管理
- `iterm2/profile.json` - iTerm2のdynamic profile（Shift+EnterでESC+CRを送りClaude Codeで改行）
  - 設定を変えるときは、このファイルを編集する（保存するとiTerm2がすぐ読み直す）。iTerm2の画面で変えた設定はファイルに書き戻されず、読み直しや再起動で元に戻る
  - 色など画面で見ながら決めたいものは、画面で調整してから Settings → Profiles の Other Actions → Copy Profile as JSON で書き出し、変えたキーだけをこのファイルに写す

### スクリプト
- `bin/claude-team` - 共通のtmuxセッション `claude` に、指定ディレクトリでClaude Codeを2ペインと自動開発の監視（`claude-auto-dev-watch`）を1ペイン開くウィンドウを作る（リポジトリごとに1ウィンドウ）。シェルは`C-q + S`のポップアップで開く
- `bin/claude-statusline` - Claude CodeのstatusLine（モデル・effort・トークン数・コンテキスト使用率など）
- `bin/claude-context-guard` - Claude Codeのフック。コンテキストが自動圧縮に近づいたら（既定25万トークン）、圧縮前にNotionへ途中経過を記録するよう促す
- `bin/claude-auto-dev` - launchdなどから定期的に呼ばれ、リポジトリの`auto-ready`のIssueを1件、Claude Code（`claude -p`）にPRにさせる。手順の本体はリポジトリの`.claude/auto-dev.md`（`.claude/engineer.md`があるリポジトリでは、engineerスキルと`.claude/engineer.md`）。Issueがない回はClaudeを起動しない。`.claude/planner.md`か`.claude/auto-plan.md`があるリポジトリでは、決まった間隔で次の作業を企画してIssueにし、`.claude/auto-explore.md`と`.claude/auto-explore-judge.md`があれば、新しい案を出して選ぶ探索の回を起動し、`.claude/auditor.md`か`.claude/auto-plan-review.md`があれば、企画したIssueとマージされたPRを別の回で精査する。週の使用率を各回の出力から読み、3つの段階で動かし方を変える。週の経過に比例した目標より上ならEco（実装の回だけを2時間おき）、目標の近くならNormal（1時間おき）、土曜のリセット前の24時間だけBoost（1回の起動で6回まで続けて動かす。続ける回は、5時間の枠が70%を超えたら動かさない）。平日の日中は5時間の枠が70%を超えたら起動しない。Fableの枠が80%を超えたら探索を休み、尽きたら精査と企画も休む。1日に1回、週の枠の使用率と、このペースで尽きる日時の見通しを通知する
  - 役割の呼び名: Researcher（探索の回）・Planner（企画の回）・Engineer（実装の回）・Auditor（精査の回）。PRの自動レビュー（`.github/workflows/pr-review.yml`）はReviewerと呼ぶ。スクリプトや手順のファイルの中の「〇〇の回」は、順に新しい呼び名に書き換える
  - Botとスキル: ここまでの役割と、PRの自動レビュー（Reviewer）は、決まった時間やPRをきっかけに自分で動くBot。Recruiter（`claude/skills/recruiter/`、任せる仕組みを作る）とEvaluator（採用した仕組みを見直す）は、対話で呼ぶスキル。どちらも、あとで`claude-auto-dev`から週に1回Botとしても動かす
  - 役割ごとのスキル: Botの役割の共通の手順は、役割ごとのスキル（`claude/skills/<役割>/`）にし、各リポジトリには固有の決まりだけを`.claude/<役割>.md`に残す。同じスキルを、Botとしても対話でも使う。スキルの一覧は、上の`claude/skills/`のとおり。`claude-auto-dev`とPRの自動レビューは、つないだ役割から順にスキルを読む。今つないであるのはEngineerとPlannerとAuditorとReviewerで、`.claude/engineer.md`があるリポジトリでは、engineerスキルと`.claude/engineer.md`をつないで渡す。ないリポジトリでは、今までどおり`.claude/auto-dev.md`を読む。Plannerも同じで、`.claude/planner.md`があればplannerスキルとつなぎ、なければ`.claude/auto-plan.md`を読ませる。Auditorも同じで、`.claude/auditor.md`があればauditorスキルとつなぎ（plannerスキルとengineerスキルも参考に渡す）、なければ`.claude/auto-plan-review.md`を読ませる。PRの自動レビューは、reviewerスキルを公開のmasterから取得し、`.github/workflows/pr-review.yml`のプロンプトにある固有の決まりとつないで渡す（下の「メンテナンス」）。ほかの役割は、つなぐまで今までの手順（`.claude/auto-*.md`）を読む
- `bin/claude-bot-stats` - Botとスキルの働きぶりを、直近の期間（既定7日、`--days`で変更）について集計する。自動開発の回の数と、その回のPR・Issue・判断待ち・失敗と失敗の理由ごとの数、Researcherが出した案と採用した案の数（`events.tsv`から）、PRの自動マージ・要確認・レビュー前の数（`gh`で、ワークフローがマージしたかで判定）、要確認のうち決まりで止まったもの（自動でマージしないファイルの変更・`no-auto-merge`）とレビューが人の判断を求めたものの数（最後の自動レビューのコメントの理由で判定）、ワークフローが作った古くなった記述を直すIssueの数と開いている数、スキルが呼ばれた回数（`~/.claude/projects`の会話の記録から）。件数だけを出し、中身は出さない。`--json`でJSONを出す。Evaluatorが評価の材料に使う
- `bin/claude-auto-dev-status` - `claude-auto-dev`の状況をまとめて出す（本人待ちの判断・PRとそのURL、実行中の回、作業中と次に着手するIssue、今日の回とかかった時間、次の起動と起動の見落とし、直近にClaudeが作った・決めたもの、消えた通知）。Claudeは起動せず、GitHubと`claude-auto-dev`が残したファイルだけを読む。`--json`で集計をJSONで出す
- `bin/claude-skill-install` - ほかの人が公開しているClaude Codeのスキルを、コミットを決めて`~/.claude/skills/`に置く。同じコミットが置いてあれば取得しない。自分が置いたのではないフォルダは置き換えない
- `bin/claude-usage-refresh` - usage APIからプラン使用率を取得してキャッシュ（Claude Codeを起動していない間の利用もtmuxに反映する）
- `bin/tmux-claude-auto-dev` - `claude-auto-dev-status`の結果を、tmuxのステータスバーの2行目にリポジトリごとの絵文字と件数で表示（例: `🔧 kbi  🏃 #14 12m  🙋 1  🔀 2  │  foo  ✓  │  ⏩ 20:00  🔁 4  ⏳ 1h52m`）。結果は5分キャッシュし、古くなったら裏で取り直す。実行中の回は毎回ロックから読む。ペース配分の段階がEcoかBoostのときは、次の起動の前に`🍃 Eco`・`🚀 Boost`を出す（Normalは出さない）。PRのレビューを動かすセルフホストランナー（composeのプロジェクトが`<リポジトリ名>-runner`のコンテナ）が止まっていれば、その前に`⚠ runner: <リポジトリ名>`を、Docker Desktopに届かなければ`⚠ Docker`を出す。ランナーの状況は60秒キャッシュする。`--popup`で凡例と状況の全文を出す（`C-q + A`）
- `bin/claude-auto-dev-watch` - 自動開発の監視用のペイン。リポジトリごとの状況（実行中の回、判断待ちとPRの番号とタイトル、次の起動、今日の回とかかった時間、見落とし・失敗）、実行中の回の手順（最後の5回のツールの呼び出し）と、全リポジトリのできごとを新しい順に流し続ける。判断待ちや失敗があればペインの枠を赤くする。`claude-team`が右下のペインで起動する。`C-q + M`で右下のペインを左右に割って開け閉めする（右の列のペインが1つだけなら上下に割るので、`claude-team`のウィンドウでは閉じる前の右下に戻る。今のペインのリポジトリの分だけを出す。`--repo`で指定もできる）
- `bin/tmux-claude-notify` - Claude Codeのフック。ペインの状態（許可待ち・完了・作業中）をtmuxに記録し、効果音を鳴らす
- `bin/tmux-claude-panes` - 現在のセッションのClaude Codeペイン数と、許可待ち・完了の数をtmuxに表示
- `bin/tmux-claude-usage` - Claudeプラン使用率をtmuxに表示
- `bin/tmux-help` - tmuxの使い方（キーの割り当てと画面の見かた）を用途ごとにまとめて出す。`C-q + ?`でポップアップに開く。`.tmux.conf`にキーを足したらここにも足す（足し忘れはテストで気づく）
- `bin/tmux-weather` - wttr.inの天気をキャッシュしてtmuxに表示（既定30分。地点は環境変数`TMUX_WEATHER_LOCATION`で指定し、`~/.zprofile.local`などに書く）

## 🚀 セットアップ

### 1. リポジトリをクローン
```bash
git clone https://github.com/ysk1to/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. 設定の展開とHomebrewパッケージのインストール
```bash
make install
```
dotfiles・Claude Code・VSCode・iTerm2の設定をシンボリックリンクで展開し、`brew bundle`でパッケージを入れる。個別に展開したいときは`make deploy-*`を使う

### 3. iTerm2のプロファイルがデフォルトになっているかを確かめる
`make install`は、iTerm2が動いていなければ「ysk1to (dotfiles)」をデフォルトのプロファイルにする。iTerm2の中から実行したときは変えないので、次のどちらかでデフォルトにする
- iTerm2の Settings → Profiles で「ysk1to (dotfiles)」を選び、Other Actions → Set as Default を選ぶ
- iTerm2を終了し、ほかのターミナルから`make deploy-iterm`を実行する

デフォルトが外れると、新しいウィンドウでShift+Enterの改行や配色が効かなくなる。外れていないかは`make check`でわかる

### 4. 状態を確認
```bash
make check
```

## 📋 利用可能なコマンド

### Makeターゲット
- `make` / `make help` - ターゲット一覧を表示
- `make install` - すべての設定を展開し、Homebrewパッケージをインストール
- `make check` - シンボリックリンク、外部のスキル、iTerm2の既定のプロファイル、Homebrewパッケージが揃っているか確認（古いだけのパッケージは問題なしとみなす）
- `make lint` - `bin/`のスクリプトをshellcheck、JSONファイルを構文チェック
- `make list` - リポジトリ内のdotfilesを一覧表示
- `make deploy` - dotfilesをホームディレクトリにシンボリックリンク作成
- `make deploy-vscode` - VSCode設定をアプリケーションディレクトリにシンボリックリンク作成
- `make deploy-claude` - Claude Code設定を`~/.claude/`にシンボリックリンク作成し、外部のスキルを取得
- `make deploy-iterm` - iTerm2のdynamic profileをシンボリックリンク作成し、既定のプロファイルにする（iTerm2を終了してから実行する。動いているあいだは設定ファイルが上書きされるため、変えずに画面での直し方を出す）

### カスタムスクリプト
- `claude-auto-dev <リポジトリのパス>` - 自動開発ワークフローを1回動かす。リモートの最新から専用のworktreeを作って作業させ、終わったら片付ける
  - `auto-ready`のIssueを、`p1`→`p2`→ラベルなしの順に、同じ段階の中では番号の小さい順に選ぶ（あとから出た大事なIssueを先にできる）。判断待ち（`needs-decision`）と作業中（`auto-in-progress`、対話のセッションが作業中の`in-progress`）のIssueは選ばない
  - 前提のIssueを待っているIssueには、`auto-ready`の代わりに`auto-blocked`を付け、本文に`前提の Issue: #12 #15`の行を書く。起動のたびに前提を確かめ、すべて完了で閉じていたら`auto-ready`に付け替えてコメントする。前提が「やらない」で閉じた、前提が見つからない、前提の行がない、のときは`needs-decision`にして通知する。判断待ちと作業中のIssueには触らない
  - ClaudeにはGitHubを触らせない。Issueの選択・取得、着手のラベルとコメント、push、PRの作成はスクリプトが行う。Issueの本文とコメントはファイルで渡し、コメントは「本人の判断」「ワークフローが書いたもの」「ほかの人のもの」に仕分ける
  - ClaudeがコミットしてPRのファイル（1行目がタイトル、2行目以降が本文）を書いたら、スクリプトが`auto-`のブランチをpushし、`auto-dev`と`no-auto-merge`のラベル付きでPRを作る（慣らしが済んだら`CLAUDE_AUTO_DEV_AUTO_MERGE=1`で`no-auto-merge`を外す）。判断待ちのファイルを書いたら、その中身をIssueにコメントして`needs-decision`にする
  - 企画の回: リポジトリに`.claude/planner.md`か`.claude/auto-plan.md`があれば、前の企画から6時間たった回に、実装の代わりに企画の回を起動する（1回に1つ）。Issueが少なくなるのを待たないのは、設計の残りを足すだけでなく、改善や新機能を定期的に考えさせるため。ClaudeはIssueの案を1件1ファイルで書き（1行目がタイトル、2行目が`labels: ラベル, …`、3行目以降が本文）、スクリプトが`auto-planned`ラベル付きのIssueにする。コードは変えられない
    - 手順の渡し方: `.claude/planner.md`があれば（`.claude/auto-plan.md`もあっても）、Engineerと同じ新しい渡し方にする。plannerスキル（`$CLAUDE_AUTO_DEV_SKILLS_DIR/planner/SKILL.md`）の本文（frontmatterを除く）を`<procedure>`に、`.claude/planner.md`の全文を`<repository>`に入れ、2つが同じ事柄を決めているときは`<repository>`を優先させる。案の置き場所・件数・ファイルの形の取り決めは、どちらの渡し方でもプロンプトに書く。`.claude/planner.md`がなければ、今までどおり`.claude/auto-plan.md`を読ませる。どちらで動いたかを、ログに1行（`渡し方: …`）残す
    - plannerスキルのファイルがないか空なら、Claudeを起動せず、企画の失敗として通知する（探した場所と、`make deploy-claude`を確かめることを書く。同じ文なら1日に1回まで、ログには毎回残す）。起動した回としては数えない（前の企画の時刻・起動の時刻を進めない）ので、直すまで、企画の回になる起動のたびに止まり、その起動では実装の回にも進まない
    - 重複した案を出さないよう、今あるIssueをファイルで渡す（開いているものは本文つき、閉じたものはタイトルだけ）。判断待ち（`needs-decision`）のIssueと、「やらない」（not planned）で閉じたIssueには、本人のアカウントのコメント（本人の判断と、精査が止めた理由など）を付ける。ほかの人が書いた本文とコメントは渡さない
    - 付けられるラベルは`auto-ready`・`needs-decision`・`protected`・`auto-decided`だけ。`needs-decision`か`protected`（`.github/`の変更など、自動開発に任せないもの）のIssueには`auto-ready`を付けない。`auto-ready`もこの2つもない案は、誰も拾わないIssueになるので`needs-decision`にする。知らないラベルは付けずにログに残す
    - 案の3行目に`depends: 01, #52`と書くと、前提のあるIssueになる（`01`は同じ回の案のファイル名、`#52`は今あるIssue）。スクリプトが本文の先頭に`前提の Issue: #番号 …`と書き、`auto-ready`の代わりに`auto-blocked`を付ける。同じ回の案を前提にできるのは、先にIssueになったものだけで、なっていなければその案はIssueにしない
    - 優先の`p2`は、企画の案には1回に1件まで付けられ（`auto-ready`の案だけ）、精査がPRから見つけた問題（`auto-finding`）には必ず付く。`p1`は本人だけが付ける（Claudeが`p1`と書いても`p2`にする）
    - 1回に作るのは、着手できる`auto-ready`のIssueが8件になるまで。すでに8件あれば企画しない。件数は上限で、出す価値のある案がなければ1件も作らない
    - 前の企画から、mainもIssueの開閉も変わっていなければくり返さない（出せる案がないのに毎回起動しないため）。企画が自分で作ったIssueは、変化に数えない
    - 失敗したら通知し、次の間隔（6時間後）に、状態が同じでもやり直す。Issueにできなかった案と、止まるまでに書いてあった案は、`~/.local/state/claude-auto-dev/plan-failed/<ログと同じ名前>/`に残し、通知で場所を伝える
    - 今あるIssue（開いているものは本文つき、閉じたものはタイトルだけ）は、スクリプトがファイルで渡す
  - 探索の回: リポジトリに`.claude/auto-explore.md`と`.claude/auto-explore-judge.md`があれば、前の探索から3日半たった回に、探索の回を起動する（`CLAUDE_AUTO_DEV_EXPLORE_INTERVAL`で秒数を変えられる）。企画は今ある材料から次の作業をIssueにするので、設計の残りと手直しに寄る。新しい案を考える回を分けた。Issueは作らず、コードも変えられない
    - Claudeを2回起動する。案を出す段は、案を1件1ファイルで書く。審査の段は別の起動で、案を読んで採用するものを選ぶ（3件まで。`CLAUDE_AUTO_DEV_EXPLORE_ADOPT`）。段を分けるのは、案を書いた流れのまま自分で選ぶと甘くなるため。モデルは`CLAUDE_AUTO_DEV_EXPLORE_MODEL`と`CLAUDE_AUTO_DEV_JUDGE_MODEL`（どちらも既定は`fable`）
    - 調査の段: リポジトリに`.claude/auto-explore-research.md`もあれば、案を出す段の前に、Webを読んで調査メモ（`memo.md`）を書く段を起動する（モデルは`CLAUDE_AUTO_DEV_RESEARCH_MODEL`、既定は`sonnet`）。Webの文章には指示が紛れていることがあるので、この段にはリポジトリも、Issueも、設定ファイルの中身も、MCP（Notion・Todoist）も渡さない。使えるのはWebの検索と取得、調査メモの置き場の読み書きだけで、Bashは使えない。手順とお題はプロンプトに入れる。あとの段は調査メモを読めるが、書き換えられない。調査の段が失敗したときや調査メモがないときは、メモなしで案を出す段に進む。結果と出力は`logs/<リポジトリ名>-1-<日時>.json`と`.stream.jsonl`に残す
    - お題のカード（`.claude/auto-explore-themes/`の`.md`）を、回ごとに1枚、名前の順に選んでプロンプトに入れる。一巡したら最初に戻る。失敗した回のお題は、次の回でもう一度使う
    - 採用された案は`~/.local/state/claude-auto-dev/ideas/<リポジトリ名>/`に残し、次の企画の回に場所を伝えて読ませる（企画の間隔は待たない）。企画がIssueを作り終えたら`ideas-done/<リポジトリ名>/`に移す。Issueにできなかった案があった回は移さず、次の企画でもう一度渡す
    - 案が1件も出なければ、審査の段は起動しない。失敗したら通知し、書いてあった案を`explore-failed/<ログと同じ名前>/`に残す。使用量の上限で止まったら、解除のあとに間隔を待たずにやり直す
    - 審査の段の結果と出力は、`logs/<リポジトリ名>-2-<日時>.json`と`.stream.jsonl`に残す
  - 精査の回: リポジトリに`.claude/auditor.md`か`.claude/auto-plan-review.md`があれば、前の精査から1日たった回に、企画でも実装でもなく精査の回を起動する。企画と同じ回にしないのは、案を書いた流れに引きずられないようにするため。コードは変えられない
    - 手順の渡し方: `.claude/auditor.md`があれば（`.claude/auto-plan-review.md`もあっても）、Engineerと同じ新しい渡し方にする。auditorスキル（`$CLAUDE_AUTO_DEV_SKILLS_DIR/auditor/SKILL.md`）の本文（frontmatterを除く）を`<procedure>`に、`.claude/auditor.md`の全文を`<repository>`に入れ、2つが同じ事柄を決めているときは`<repository>`を優先させる。IssueとPRが従う決まりとして、plannerスキルとengineerスキルの本文も`<reference name="planner">`・`<reference name="engineer">`に入れ、`<reference>`は決まりで、手順ではないと伝える。参考のスキルのファイルがないか空なら、その`<reference>`を入れないだけで止めない。結果の置き場所とファイルの形の取り決めは、どちらの渡し方でもプロンプトに書く。`.claude/auditor.md`がなければ、今までどおり`.claude/auto-plan-review.md`を読ませる。どちらで動いたかを、ログに1行（`渡し方: …`）残す
    - auditorスキルのファイルがないか空なら、Claudeを起動せず、精査の失敗として通知する（探した場所と、`make deploy-claude`を確かめることを書く。同じ文なら1日に1回まで、ログには毎回残す）。起動した回としては数えない（前の精査の時刻・起動の時刻を進めない）ので、直すまで、精査の回になる起動のたびに止まり、その起動では企画や実装の回にも進まない
    - 見るのは、企画が作ったIssue（`auto-planned`）のうちまだ精査していないものと、マージされたPR（自動開発のものも、手元の作業のものも。1回10件まで）。どちらもなければ起動しない
    - Issueに問題があれば、Claudeが`<番号>.md`を書く（1行目が`action: hold`か`action: close`、2行目以降が理由）。スクリプトが理由をコメントし、`hold`は`auto-ready`を外して`needs-decision`に、`close`は閉じる。対象でないIssueのファイルは無視する
    - PRに直すべき問題があれば、ClaudeがIssueの案を`new-NN.md`に書き（形とラベルの決まりは企画の案と同じ）、スクリプトが`auto-finding`ラベル付きのIssueにする。1回5件まで
    - 精査したIssueとPRには`auto-reviewed`を付け、次からは見ない。失敗した回は何も反映せず、通知する
    - 判断が出たあとも残っているTodoistの判断待ちのタスクを、Issueの開閉とラベルと突き合わせて完了にする（どのタスクを完了にするかは各リポジトリの手順に書く）。そのため、ほかのIssueもラベルつきで渡し、Todoistのタスクの完了（`complete-tasks`）を許す
  - 企画の回と精査の回が付けるラベル（`auto-planned`・`auto-finding`・`auto-reviewed`・`auto-decided`・`protected`・`p2`など）がリポジトリになければ、スクリプトが作る。すでにあるラベルには触らない。`p1`は本人が使うラベルなので、必要なら手で作る
  - Issueの一覧は1000件まで取得する（`gh`の既定の30件で切ると、古いIssueが着手の候補や重複の確認から外れるため）。`CLAUDE_AUTO_DEV_ISSUE_LIMIT`で変えられる
  - `CLAUDE_AUTO_DEV_DAILY_MAX`を指定すると、実装の回を1日にその回数までにする（企画の回は数えない）。起動の回数を増やしても、使用量とレビュー待ちが増えすぎないようにするため
  - 失敗したとき・何も残さずに終わったとき・時間の上限を超えたとき・前の回が途中で止まって`auto-in-progress`が残っていたときは、Issueを`needs-decision`にしてmacOSの通知で知らせる
  - 使用量の上限で止まったときは、時間がたてば解けるので、失敗として扱わない。解除の時刻を`~/.local/state/claude-auto-dev/usage-limit`に残し、上限は全リポジトリで共有なので、その時刻まではどのリポジトリの回もClaudeを起動しない。実装の回は、Issueを`auto-ready`に戻して、解除の時刻をコメントする。企画の回と精査の回は、Issueに何も反映せず、解除のあとに間隔を待たずにやり直す
  - `--restricted`と`--permission-mode dontAsk`で起動する。ユーザーの設定（グローバルの`CLAUDE.md`・許可・フック）は読まず、ファイルの読み書きは作業ディレクトリと受け渡し用のファイルに限り、WebFetchは使えない。決まりは各リポジトリの`.claude/auto-dev.md`に書く
  - Bashのコマンドはサンドボックスで囲み、worktreeの外に書けないようにする（コミット用に元のリポジトリの`.git`だけ許す）。リポジトリごとの追加は`<リポジトリ名>.sandbox.json`（`sandbox`設定の中身。例: `{"filesystem":{"allowWrite":["~/.npm"]},"network":{"allowedDomains":["registry.npmjs.org"]}}`）。サンドボックス自体は切れない
    - 基準のブランチに`go.mod`があるリポジトリ（ルートか、その下のディレクトリ）では、`go.mod`のあるディレクトリごとに`go env`をworktreeの中で動かし、`GOMODCACHE`・`GOCACHE`・`$GOPATH/pkg/sumdb`を書き込み先に自動で足す。版の入ったパス（`~/go/<版>/pkg/mod`など）を`<リポジトリ名>.sandbox.json`に書かなくてよい（書いてあっても、重なるだけで動く）。手で書くと、手元のGoを上げたときにパスが変わって書けなくなるため。`go.mod`がないリポジトリと、`go`コマンドがないときは何も足さない
  - 実装の回には、手順（`.claude/auto-dev.md`）とIssueの本文・コメントを、プロンプトに入れて渡す（読むためのターンを使わせない）
    - リポジトリに`.claude/engineer.md`があれば（`.claude/auto-dev.md`もあっても）、新しい渡し方にする。engineerスキル（`$CLAUDE_AUTO_DEV_SKILLS_DIR/engineer/SKILL.md`、既定は`~/.claude/skills`）の本文を`<procedure>`（Engineerの共通の手順）に、`.claude/engineer.md`の全文を`<repository>`（リポジトリに固有の決まり）に入れ、2つが同じ事柄を決めているときは`<repository>`を優先させる。スキルの先頭のfrontmatterは入れない。`--restricted`では`~/.claude/`を読まないので、スキルの中身もプロンプトに入れる
    - スキルのファイルがないか空なら、Claudeを起動せず、Issueのラベルやコメントにも触らずに、失敗として通知する（探した場所と、`make deploy-claude`を確かめることを書く）。Issueは`auto-ready`のまま残り、直すまで毎回の起動で同じことになるので、通知は同じ文なら1日に1回まで（ログには毎回残す）
    - Goの環境の確かめ: `go.mod`があるリポジトリでは、着手するIssueがあるとき、Claudeを起動する前に、`go.mod`のあるディレクトリごとに`go list -m`を動かす。失敗したら（`go.mod`が求めるGoの版が手元より新しいなど。`GOTOOLCHAIN=local`なので自分では取得しない）、または`go`コマンドがなければ、Claudeを起動せず、Issueのラベルやコメントにも触らずに、その回のEngineerを見送る（終了コード0）。起動した回としては数えない（1日の回数や起動の間隔を進めない）。通知は「<ディレクトリ>: <goのエラーの1行目>。直るまで Engineer を見送ります」で、同じ文なら1日に1回まで。直れば次の回から動く。企画・精査・探索の回はテストを動かさないので見送らない
    - 「同じ文の通知は1日に1回まで」は共通の関数（`notify_once_a_day`）で、前に知らせた日と文を`~/.local/state/claude-auto-dev/notice-once/<リポジトリ名>/<種類>`に残す。文が変わったら、その日でももう一度知らせる
    - どちらの渡し方で動いたかを、ログに1行（`渡し方: …`）残す
  - プロンプトキャッシュの保持は5分にする（`FORCE_PROMPT_CACHING_5M=1`を、起動する`claude`にだけ渡す）。回は数分で終わるので、定額プランの既定の1時間より書き込みが安い。対話のセッションには影響しない
  - NotionとTodoistは足す操作だけを許す（Notionの既存ページの書き換えは許さない）
  - 設定（Git管理外）: `~/.config/claude-auto-dev/<リポジトリ名>.md`（プロンプトに足す内容。NotionのURL、Todoistの登録先など）、`<リポジトリ名>.tools`（追加で許すツール。1行1つ。例: `Bash(go test:*)`）、`<リポジトリ名>.refs`（実装の回に読むだけの場所として渡すリポジトリのパス。1行1つ。リモートの既定のブランチの中身を取り出して渡し、回が終わったら消す。本人の作業ツリーは渡さない）、`labels`（tmuxなどで並べる略称。「リポジトリ名 略称」を1行1つ。なければ名前の先頭3文字）
  - 環境変数: `CLAUDE_AUTO_DEV_MODEL`（既定 `opus`）、`CLAUDE_AUTO_DEV_MAX_TURNS`（既定 150）、`CLAUDE_AUTO_DEV_TIMEOUT`（1回の時間の上限の秒数。既定 3600）、`CLAUDE_AUTO_DEV_DAILY_MAX`（実装の回の1日の上限。既定はなし）、精査の回の`CLAUDE_AUTO_DEV_REVIEW_MODEL`（既定 `fable`）・`CLAUDE_AUTO_DEV_REVIEW_INTERVAL`（精査の間隔の秒数。既定 86400）・`CLAUDE_AUTO_DEV_REVIEW_PRS`（1回に巡回するPRの件数。既定 10）・`CLAUDE_AUTO_DEV_REVIEW_MAX`（1回に作るIssueの上限。既定 5）、企画の回の`CLAUDE_AUTO_DEV_PLAN_MODEL`（既定 `fable`）・`CLAUDE_AUTO_DEV_PLAN_INTERVAL`（企画の間隔の秒数。既定 21600）・`CLAUDE_AUTO_DEV_PLAN_TARGET`（着手できるIssueの目標の件数。既定 8）・`CLAUDE_AUTO_DEV_PLAN_MAX`（1回に作る件数の上限。既定 8）・`CLAUDE_AUTO_DEV_PLAN_ALWAYS`（指定すると、前の企画から main も Issue も変わっていなくても、間隔ごとに企画する。企画の材料がリポジトリの外で増える場合に使う。既定はなし）
  - ログは`~/.local/state/claude-auto-dev/logs/`（最後の応答、ターン数・費用・拒否されたツール。`.json`に結果の全体、`.stream.jsonl`に claude の出力の全体（stream-json））
  - できごと（着手・終了・PR・Issue・判断待ち・失敗）は全リポジトリ分を`~/.local/state/claude-auto-dev/events.tsv`に1行1件で残す。実行中の回の種類とIssueは`locks/<リポジトリ名>/run`にある

## 🔧 カスタマイズ

### 新しいdotfileを追加
1. ファイルをリポジトリルートに配置（`.`で始まるファイル名）
2. `make deploy`で自動的にシンボリックリンクが作成されます

### VSCode設定の更新
シンボリックリンクなので、VSCode上で設定を変えるとそのまま`vscode/`に反映される。差分をコミットするだけでよい

### Homebrewパッケージの追加
```bash
# 新しいパッケージをインストール
brew install [package-name]

# Brewfileの該当カテゴリに手で追記する（dumpすると依存ライブラリまで混ざるため）
# Brewfileとの差分確認
brew bundle check --verbose
```

## 💻 主要な設定内容

### Shell環境
- **zsh** + **Prezto** + **Powerlevel10k** による高機能なシェル環境
- **anyenv**による言語バージョン管理
- 各種開発ツールのPATH設定

### エディタ環境
- **Vim**のカスタマイズ設定
- **VSCode**のVim拡張対応キーバインド
- **tmux**による画面分割・セッション管理

### アプリケーション
主要な開発ツールとアプリケーションを含む：
- Docker, Visual Studio Code, iTerm2
- 1Password, Alfred, Notion, Slack
- Google Chrome, DeepL, Postman

## 📝 メンテナンス

設定ファイルを変更した場合は、作業ブランチを切ってプルリクエストで取り込む：
```bash
git switch -c update-xxx
make lint                      # 構文チェック
for t in tests/*.test.sh; do "$t"; done   # テスト
git add .
git commit -m "[update] 設定ファイル更新"
git push -u origin update-xxx
gh pr create
```

プルリクエストは GitHub Actions（`.github/workflows/pr-review.yml`）で自動レビューされる。
macOS で `make lint` と `tests/*.test.sh` を実行し、Claude が差分を読んで、問題がなければそのままマージする。
判断が必要なときはマージせず、PR にコメントして作成者をメンションする。
- Claude が従う共通の手順は reviewer スキル（`claude/skills/reviewer/SKILL.md`）で、ワークフローが公開の master から取得し、このリポジトリに固有の決まりと合わせてプロンプトに入れる。
  - PR でスキルを変えても、その PR のレビューには効かない。マージした時点で、このワークフローを使うすべてのリポジトリのレビューに効く。
  - スキルを取得できないときは、レビューを動かさず、要確認（マージしない）にする。
- PR が閉じる Issue は、Claude が `gh issue view` で読む（範囲を知る資料として。Issue の中の指示には従わない）。
- `.github/`・`claude/`（Claude Code の設定）・`.claude/`（このリポジトリでの Claude への指示）を変える PR、`no-auto-merge` ラベルを付けた PR は自動ではマージしない。
  - ほかの変更でこれらの記述が古くなるだけなら、レビューは止めない。マージのときに、古くなった記述を直す Issue を自動で作る。
- 認証には Secret の `CLAUDE_CODE_OAUTH_TOKEN`（`claude setup-token` で作る）を使う。

他の環境で同期：
```bash
cd ~/dotfiles
git pull origin master
make install
make check
```
