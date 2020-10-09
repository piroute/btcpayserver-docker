import sys, os
import json
from btclib import bip32, wif
import time, subprocess, pty
import re

# Make sure we run lnd
BTCPAYGEN_LIGHTNING = os.environ['BTCPAYGEN_LIGHTNING']
if BTCPAYGEN_LIGHTNING != 'lnd':
  sys.exit("This script only works with lnd internal lightning node")

# Make sure we have the seed
NBITCOIN_NETWORK = os.environ['NBITCOIN_NETWORK']
walletUnlockPath = "/var/lib/docker/volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/{}/walletunlock.json".format(NBITCOIN_NETWORK)
if not os.path.isfile(walletUnlockPath):
  sys.exit("walletunlock.json file does not exist at {}. Make sure the node is synchronised".format(walletUnlockPath))

# Get the mnemonic
cipher_seed_mnemonic = []
with open(walletUnlockPath) as json_file:
  data = json.load(json_file)
  cipher_seed_mnemonic = " ".join(data['cipher_seed_mnemonic'])
if len(cipher_seed_mnemonic)==0:
  sys.exit("cipher_seed_mnemonic {}".format(walletUnlockPath))

# Chantools extracts master privatekey from seed
master_fd,slave_fd = pty.openpty()
p = subprocess.Popen(['chantools showrootkey'], 
  stdin=slave_fd, 
  stdout=subprocess.PIPE, 
  stderr=subprocess.PIPE, 
  shell=True)
master_fo = os.fdopen(master_fd, 'w')
master_fo.write("{}\n\n".format(cipher_seed_mnemonic))
time.sleep(0.5)
master_fo.close()
chantoolsExitCode = p.poll()
if (chantoolsExitCode != 0):
  sys.exit("chantools terminated with error {}".format(chantoolsExitCode))

p.stdout.readline()
p.stdout.readline()
p.stdout.readline()
p.stdout.readline()
chantoolsOutput = p.stdout.readline().decode("UTF-8")
# 'Your BIP32 HD root key is: xprvXXXYYYZZZ\n'
m = re.search('Your BIP32 HD root key is: ([A-Za-z0-9]+)\n', chantoolsOutput)
if not m:
  sys.exit("cannot retrieve master priv in {}".format(chantoolsOutput))
masterPriv = m.group(1)

# Selecting cointype; apparently with LND cointype is 0 also in the testnet derivation
COIN_TYPE = 0 
if NBITCOIN_NETWORK == "testnet": COIN_TYPE = 0

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
