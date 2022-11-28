# Configuring yubikeys

## Setting up your yubikeys (if you do not have yubikeys, skip to next section)

For each yubikey you have, do steps 1-7:

1. Insert the yubikey and make sure gpg has access to it
   ```
   gpg --card-status
   ```
   You should see a dump of info about your yubikey here.
   If you do not, a few things you can try are:
   
   * re-insert the yubikey
   * kill the gpg-agent process
   * `systemctl restart pcscd`

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

5. Somewhere reasonably safe (and backed up), create a subdirectory for this specific yubikey and store a revokation certificate and the gpg and ssh-formatted versions of the public key:
   ```
   mkdir <yubikey id>
   cd <yubikey id>

   gpg --output yubikey-revoke.asc --gen-revoke "$KEYID"

   gpg --armor --export "$KEYID" > yubikey-public-gpg.asc
   gpg --export-ssh-key "$KEYID" > yubikey-public-ssh.pub
   ```

6. Before continuing, one often need to stop gpg-agent since it tends to "lock" other use of the yubikey.
   When gpg is invoked, it will auto-start gpg-agent again (and thus will require you to stop it again for some uses of the yubikey).
   ```
   gpgconf --kill gpg-agent
   ```

7. We now want to create a special ssh authentication piv key.

   This key will be setup to only require pin once to unlock, and no touch, which makes it less secure, since a rogue process running on your machine could re-invoke the key any number of times once it is unlocked.
   However, this key will only be used to identify us over ssh for running a few select fairly safe commands that we want to be able to run over a large number of systems, where the requirement to touch the yubikey for each connection would be cumbersome.

   To avoid conflict with other uses of the piv slots, we use slot 95 for this, which is the last one of the "retired key management" slots (named "Retired Key 20").
   ```
   yubico-piv-tool -s 95 -A ECCP256 -a generate -o piv95-public.pem --pin-policy=once --touch-policy=never
   yubico-piv-tool -a verify-pin -a selfsign-certificate -s 95 -S "/CN=SSH key slot 95/" -i piv95-public.pem -o piv95-cert.pem
   yubico-piv-tool -a import-certificate -s 95 -i piv95-cert.pem
   ```

8. Export the piv keys in ssh format
   ```
   ssh-keygen -D libykcs11.so -e | grep "Public key for Retired Key 20" > yubikey-public-ssh-piv95.pub
   ```
   
9. Repeat steps 1-7 for all yubikeys you have to set up.
   When finished, make sure your current working directory have all key directories as subdirectories.

10. Create files that collect all these public ssh keys, per user:
   ```
   cat */yubikey-public-ssh.pub > authorized_keys.<control username>
   cat */yubikey-public-ssh-piv95.pub | awk '{print "command=\"/usr/control/puppet-apply\"",$0}' > authorized_keys_auto.<control username>
   ```

11. Create a file that collect all the gpg signature keys:
    ```
    cat */yubikey-public-gpg.asc > trusted_keys.asc
    ```
