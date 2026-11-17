# xbox-one-isdbc-dkms

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)
[![DKMS](https://img.shields.io/badge/DKMS-enabled-brightgreen.svg)]()
[![Kernel](https://img.shields.io/badge/Linux%20Kernel-6.8%2B-orange.svg)]()

Microsoft Xbox One Digital TV Tuner（`045e:02d5`）で日本のケーブルテレビ ISDB-C（トランスモジュレーション方式、64QAM・256QAM、5.274 MS/s）を受信できるようにするための DKMS カーネルモジュールおよびパッチセットです。

DKMS driver and patch set for enabling ISDB-C (Japanese 6 MHz CATV, 5.274 MS/s, 64QAM/256QAM) reception on the Microsoft Xbox One Digital TV Tuner (`045e:02d5`) under Linux (Kernel 6.8+).

---

## 概要

Xbox One Digital TV Tuner は以下のチップセットで構成されており、ハードウェアとしては DVB-T/T2/C（Annex A/B/C）に対応しています。
- USB ブリッジ: DiBcom DiB0700
- 復調 IC (Demodulator): Panasonic MN88472
- シリコンチューナー: NXP TDA18250

しかし、Linux 標準（Upstream）のカーネルドライバには以下の問題があり、日本の CATV（ISDB-C）を受信できませんでした。

1. チューナードライバ（`tda18250.c`）
   - DVB-C 規格上、ロールオフ 0.15、シンボルレート 5.274 MS/s の計算帯域が `6,065,100 Hz` となり、標準ドライバの 6MHz 帯域判定閾値 `<= 6000000` を超えて 8MHz フィルタ（`DVBC_8`）が誤って選択され、隣接チャネルの混信を受ける。
   - IF フィルタ設定テーブル `delsys_params[DVBC_6]` の中心周波数が 6MHz 用の `3950 kHz` ではなく誤った周波数になっている。
   - AGC（自動利得制御）の閾値が過大入力によりサチュレーションを起こす。
2. 復調ドライバ（`mn88472.c`）
   - 日本の CATV 伝送規格である `SYS_DVBC_ANNEX_C` の Delivery System 定義が欠落している。
   - 復調引き込み待ち時間（`min_delay_ms`）が短く、キャリアロック前にタイムアウトする。

本リポジトリは上記の問題を修正したドライバモジュール（`tda18250` および `mn88472`）を DKMS パッケージとして提供します。

---

## 特徴

- ISDB-C 受信対応: 64QAM / 256QAM、5.274 MS/s、6MHz CATV チャンネルにおいて 0.7 秒以下でキャリアロックします。
- DKMS 対応: カーネルのアップデート（`apt upgrade` など）後も自動的にモジュールが再構築・再インストールされ、継続して利用できます。
- 録画・視聴環境への対応: [denpa](https://github.com/danything/denpa) による CATV チューナーの自動認識・視聴・録画、`dvbv5-zap` / `dvbv5-scan`、`Tvheadend`、`Mirakurun` などの環境に対応します。

---

## 動作確認環境

- OS: Ubuntu 22.04 LTS / 24.04 LTS (x86_64)
- Kernel: Linux 6.8.0-138-generic, 6.8.0-149-generic
- ハードウェア: ThinkCentre M73 / M720q, QEMU/KVM 仮想マシン
- チューナー: Microsoft Xbox One Digital TV Tuner (USB ID `045e:02d5`)
- 受信実績: J:COM CATV (CATV 帯域 C13〜C63、VHF/UHF 帯域、TSMF 搬送波)

---

## 必要条件

### 1. ビルドツールと DKMS
```bash
sudo apt-get update
sudo apt-get install -y dkms build-essential linux-headers-$(uname -r)
```

### 2. ファームウェア
チューナーの動作には、以下のファームウェアが `/lib/firmware/` に配置されている必要があります。
- `dvb-usb-dib0700-1.20.fw`
- `dvb-demod-mn88472-02.fw`

Ubuntu などで配置されていない場合は、以下を実行して取得してください。
```bash
sudo curl -fsSL -o /lib/firmware/dvb-usb-dib0700-1.20.fw \
  https://raw.githubusercontent.com/LibreELEC/dvb-firmware/master/firmware/dvb-usb-dib0700-1.20.fw

sudo curl -fsSL -o /lib/firmware/dvb-demod-mn88472-02.fw \
  https://raw.githubusercontent.com/LibreELEC/dvb-firmware/master/firmware/dvb-demod-mn88472-02.fw
```

---

## インストール手順

### スクリプトによるインストール
```bash
git clone https://github.com/kiwi-93/xbox-one-isdbc-dkms.git
cd xbox-one-isdbc-dkms
sudo ./install.sh
```

### 手動でのインストール
```bash
# 1. ソースを /usr/src に配置
sudo cp -r . /usr/src/xbox-one-isdbc-1.0.0

# 2. DKMS 登録とビルド・インストール
sudo dkms add -m xbox-one-isdbc -v 1.0.0
sudo dkms build -m xbox-one-isdbc -v 1.0.0
sudo dkms install -m xbox-one-isdbc -v 1.0.0

# 3. ドライバのリロード
sudo modprobe -r dvb_usb_dib0700 mn88472 tda18250 2>/dev/null || true
sudo modprobe dvb_usb_dib0700
```

ステータスを確認し、`installed` と表示されれば完了です。
```bash
$ dkms status -m xbox-one-isdbc
xbox-one-isdbc/1.0.0, 6.8.0-149-generic, x86_64: installed
```

---

## 動作確認

### 1. デバイスノードの確認
チューナーを接続すると、`/dev/dvb/adapter0/` が作成されます。
```bash
ls -la /dev/dvb/adapter0/
# frontend0, demux0, dvr0, net0 が存在することを確認
```

### 2. denpa でのテスト
denpa の `tuner-agent` を使い、チャンネルの選局をテストできます。
```bash
# 例: QC18 (141.000 MHz) を選局
docker compose run --rm tuner-agent --tune /dev/dvb/adapter0/frontend0 QC18
```
成功時の出力例
```text
/dev/dvb/adapter0/frontend0 を開きました
--- QC18  141000000 Hz ISDB-C
    同期 691 ms
    DVB-C Annex C  変調は自動 (QAM_AUTO)  5274 kbaud  受けた周波数 141000000 Hz
    ISDB-C: ロックしました
    C/N 32.4 dB
    同期バイト 100.0%  連続性の飛び 0 回  transport_error_indicator 0 個
```

### 3. dvbv5-zap でのテスト
```bash
cat << 'EOF' > isdb_c_test.conf
[QC18]
	DELIVERY_SYSTEM = DVBC/ANNEX_A
	FREQUENCY = 141000000
	SYMBOL_RATE = 5274000
	MODULATION = QAM/64
	INVERSION = AUTO
EOF

dvbv5-zap -c isdb_c_test.conf -m QC18 -v
```

---

## アンインストール

### スクリプトによるアンインストール
```bash
cd xbox-one-isdbc-dkms
sudo ./uninstall.sh
```

### 手動でのアンインストール
```bash
sudo dkms remove -m xbox-one-isdbc -v 1.0.0 --all
sudo rm -rf /usr/src/xbox-one-isdbc-1.0.0
sudo modprobe -r dvb_usb_dib0700 mn88472 tda18250 2>/dev/null || true
sudo modprobe dvb_usb_dib0700
```

---

## 修正パッチ

`patches/` ディレクトリにパッチファイルを格納しています。
- `patches/0001-media-tda18250-fix-6MHz-DVB-C-IF-filter-IF-center-an.patch`
- `patches/0002-media-mn88472-add-SYS_DVBC_ANNEX_C-support-and-incre.patch`
- `patches/combined-isdb-c.patch` (全差分統合パッチ)

Linux 6.8 の upstream コードとの差分を確認するには、以下のコマンドを実行します。
```bash
git diff v6.8-upstream..v1.0.0 -- tda18250.c mn88472.c
```

---

## ライセンス

Linux カーネルの該当ドライバに準じ、GPL-2.0 でライセンスされています。詳細は [LICENSE](LICENSE) を参照してください。
