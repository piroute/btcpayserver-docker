import sys, os
import json
from btclib import bip32, wif
import time, subprocess, pty
import re

masterPriv = sys.argv[1]

# Selecting cointype; apparently with LND cointype is 0 also in the testnet derivation
COIN_TYPE = 0 
NBITCOIN_NETWORK = os.environ['NBITCOIN_NETWORK']
if NBITCOIN_NETWORK == "testnet": COIN_TYPE = 1

print("-------------------------")
print("P2WKH Derivation (native)")
print("-------------------------")

xpriv = bip32.derive(masterPriv, f"m/84'/{COIN_TYPE}'/0'")
xpub = bip32.xpub_from_xprv(xpriv)
print(f"xpub = {xpub.decode()}")

for i in range(10):
  xpriv = bip32.derive(masterPriv, f"m/84'/{COIN_TYPE}'/0'/0/{i}")
  xprivParsed = bip32.parse(xpriv)
  keywif = wif.wif_from_prvkey(xprivParsed['key'][1:], network=NBITCOIN_NETWORK)
  address = wif.p2wpkh_address_from_wif(keywif)
  print(f"address{i} = {address.decode()}")

print(" ")
print("--------------------------")
print("NP2WKH Derivation (nested)")
print("--------------------------")

xpriv = bip32.derive(masterPriv, f"m/49'/{COIN_TYPE}'/0'")
xpub = bip32.xpub_from_xprv(xpriv)
print(f"xpub = {xpub.decode()}")

for i in range(10):
  xpriv = bip32.derive(masterPriv, f"m/49'/{COIN_TYPE}'/0'/0/{i}")
  xprivParsed = bip32.parse(xpriv)
  keywif = wif.wif_from_prvkey(xprivParsed['key'][1:], network=NBITCOIN_NETWORK)
  address = wif.p2wpkh_p2sh_address_from_wif(keywif)
  print(f"address{i} = {address.decode()}")
