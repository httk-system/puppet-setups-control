# Configuring yubikeys

## Setting up your yubikeys (if you do not have yubikeys, skip to next section)

For each yubikey you have, do steps 1-7:

1. Insert the yubikey and make sure gpg has access to it
   ```
   gpg --card-status
   ```
   You should see a dump of info about your yubikey here.
   If you do not, a few things you can try are:
   (i) re-insert the yubikey;
   (ii) kill the gpg-agent process;
   (iii) `systemctl restart pcscd`.

2. Secure the PINs and settings for the apps we will use.

   Note: *the default pin is 123456* and *the default puk is 123456768*.
   ```
   gpg --change-admin-pin
   gpg --change-pin
   yubico-piv-tool -a change-puk
   yubico-piv-tool -a change-pin
   ykman openpgp keys set-touch aut on
   ykman openpgp keys set-touch sig on
   ykman openpgp keys set-touch enc on
   ```

3. Create gpg keys on the device itself.
   (Note: I highly recommend *against* advice in other tutorials to generate the keys outside of the yubikey and then store them on the device.
   In my opinion, this leads to a significantly reduced overall security in your setup to allow the crytographic keys to exist outside of the hardware protection provided by the yubikey).
   ```
   gpg --edit-card
   ```
   In the promt that appear, write `admin`, `key-attr` and select "ECC" and "Curve 25519" for all three types of keys. Then generate keys with `generate`.
   Set expiry to 1 year.

4. Get the key id for the key you just generated:
   ```
   KEYID=$(gpg --card-status --with-colons | grep "^fpr:" | awk -F: '{print $2}')
   ```

5. Somewhere reasonably safe (and backed up),
   create a subdirectory for this specific yubikey and store
   a revokation certificate and the gpg and ssh-formatted
   versions of the public key:
   ```
   mkdir <yubikey id>
   cd <yubikey id>

   gpg --output yubikey-revoke.asc --gen-revoke "$KEYID"

   gpg --armor --export "$KEYID" > yubikey-public-gpg.asc
   gpg --export-ssh-key "$KEYID" > yubikey-public-ssh.pub
   ```

6. We also want to create two special ssh authentication piv keys.
   These keys will be setup to only require pin once per session and
   no touch, which makes them less secure, since a rogue process
   running on your machine could invoke their use unlimited.
   However, we will use these keys to identify us over ssh to
   be able to run commands on all managed systems and having to
   touch the yubikey for each such connection would be cumbersome.
   Hence, we will set things up so that the actions these key
   can peform are very limited.

   We will use slot 94 and 95 for this, which are the last of the
   "retired key management" slots.
   ```
   yubico-piv-tool -s 95 -A ECCP256 -a generate -o piv95-public.pem --pin-policy=once --touch-policy=never
   yubico-piv-tool -a verify-pin -a selfsign-certificate -s 95 -S "/CN=SSH key slot 95/" -i piv95-public.pem -o piv95-cert.pem
   yubico-piv-tool -a import-certificate -s 95 -i piv95-cert.pem

   yubico-piv-tool -s 94 -A ECCP256 -a generate -o piv94-public.pem --pin-policy=once --touch-policy=never
   yubico-piv-tool -a verify-pin -a selfsign-certificate -s 94 -S "/CN=SSH key slot 94/" -i piv94-public.pem -o piv94-cert.pem
   yubico-piv-tool -a import-certificate -s 94 -i piv94-cert.pem
   ```

7. Export the piv keys in ssh format
   ```
   ssh-keygen -D libykcs11.so -e | grep "Public key for Retired Key 20" > yubikey-public-ssh-piv95.pub
   ssh-keygen -D libykcs11.so -e | grep "Public key for Retired Key 19" > yubikey-public-ssh-piv94.pub
   ```
   
8. Repeat steps 1-7 for all yubikeys you have to set up.
   When finished, make sure your current working directory have all key directories as subdirectories.

9. Create files that collect all these public ssh keys, per user:
   ```
   cat */yubikey-public-ssh.pub > authorized_keys.<control username>
   cat */yubikey-public-ssh-piv95.pub | awk '{print "command=\"/usr/control/puppet-apply\"",$0}' > authorized_keys_apply.<control username>
   cat */yubikey-public-ssh-piv94.pub | awk '{print "command=\"/usr/control/system-update"}' > authorized_keys_update.<control username>
   ```

10. Create a file that collect all the gpg signature keys:
    ```
    cat */yubikey-public-gpg.asc > trusted_keys.asc
    ```

## Setting up gnupg keys (skip if using yubikeys)

(To be added)
