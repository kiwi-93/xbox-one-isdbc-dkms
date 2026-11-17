# xbox-one-isdbc DKMS Driver (Linux 6.8)

DKMS package and Git patch set enabling **ISDB-C (Japanese 6 MHz CATV, 5.274 MS/s, 64QAM/256QAM)** reception on the **Microsoft Xbox One Digital TV Tuner (`045e:02d5`)** (`tda18250` silicon tuner + `mn88472` demodulator).

## Root Causes & Fixes

1. **`tda18250.c`**:
   - Under `SYS_DVBC_ANNEX_A` (rolloff `1.15`) at `5,274,000 sym/s`, Linux DVB computes `bandwidth_hz = 6,065,100` Hz, which missed `<= 6000000` and selected `DVBC_8` (8 MHz IF filter at 4950 kHz), admitting upper-adjacent 6 MHz CATV interference.
   - Updated the `DVBC_6` threshold to `<= 6100000` Hz, updated `delsys_params[DVBC_6]` to use a true 6 MHz IF filter centered at `3950 kHz` (`{ 0x51, 0x03, 0x83, ... }`, `if_khz = 3950`), and unified `tda18250_set_agc()` to use non-overloading CATV AGC thresholds.
2. **`mn88472.c`**:
   - Added `SYS_DVBC_ANNEX_C` delivery system support alongside `SYS_DVBC_ANNEX_A`.
   - Increased `s->min_delay_ms` from `1000` to `1500` ms in `mn88472_get_tune_settings()`.

## Git Patch Workflow

- View combined diff against Linux v6.8 upstream:
  ```bash
  git diff v6.8-upstream..v1.0.0 -- tda18250.c mn88472.c
  ```
- Exported patches in `patches/`:
  - `patches/0001-media-tda18250-fix-6MHz-DVB-C-IF-filter-IF-center-an.patch`
  - `patches/0002-media-mn88472-add-SYS_DVBC_ANNEX_C-support-and-incre.patch`
  - `patches/combined-isdb-c.patch`

## DKMS Usage

```bash
sudo cp -a . /usr/src/xbox-one-isdbc-1.0.0
sudo dkms add -m xbox-one-isdbc -v 1.0.0
sudo dkms build -m xbox-one-isdbc -v 1.0.0
sudo dkms install -m xbox-one-isdbc -v 1.0.0
dkms status
```

To remove and revert to in-tree modules:

```bash
sudo dkms remove -m xbox-one-isdbc -v 1.0.0 --all
```
