{
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  opCli = "${pkgs._1password-cli}/bin/op";
  opConfigDir = "${homeDirectory}/.config/1password";
  opServiceAccountTokenFile = "${opConfigDir}/service-account-token";
  opServiceAccountTokenRef = "op://Personal/7fc73377vwkiokkzs643wjjpwu/service_account_token";
  notchNookLicenseItemId = "2wlfl2luotpvi6qnjeovnfm6ra";
in
{
  system.activationScripts.notchNookLicense.text = ''
    if [ -x "${opCli}" ]; then
      service_account_token=""

      if [ -r "${opServiceAccountTokenFile}" ]; then
        service_account_token=$(/usr/bin/head -n 1 "${opServiceAccountTokenFile}" 2>/dev/null || true)
      fi

      if [ -z "$service_account_token" ]; then
        bootstrap_token=$(/usr/bin/sudo -u ${username} env HOME=${homeDirectory} ${opCli} read '${opServiceAccountTokenRef}' 2>/dev/null || true)

        if [ -n "$bootstrap_token" ]; then
          /usr/bin/sudo -u ${username} /bin/mkdir -p "${opConfigDir}"
          /usr/bin/sudo -u ${username} /bin/sh -c 'umask 077 && printf %s "$1" > "$2"' -- "$bootstrap_token" "${opServiceAccountTokenFile}"
          service_account_token="$bootstrap_token"
        fi
      fi

      notch_nook_email=""
      notch_nook_key=""

      if [ -n "$service_account_token" ]; then
        notch_nook_email=$(/usr/bin/sudo -u ${username} env HOME=${homeDirectory} OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" ${opCli} read 'op://Private/${notchNookLicenseItemId}/reg_email' 2>/dev/null || true)
        notch_nook_key=$(/usr/bin/sudo -u ${username} env HOME=${homeDirectory} OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" ${opCli} read 'op://Private/${notchNookLicenseItemId}/reg_code' 2>/dev/null || true)
      fi

      if [ -n "$notch_nook_email" ] && [ -n "$notch_nook_key" ]; then
        notch_nook_key_active=$(${pkgs.jq}/bin/jq -cn \
          --arg email "$notch_nook_email" \
          --arg key "$notch_nook_key" \
          '{ email: $email, key: $key }')

        /usr/bin/sudo -u ${username} env HOME=${homeDirectory} \
          /usr/bin/defaults write lo.cafe.NotchNook keyActive -string "$notch_nook_key_active"
      fi
    fi
  '';
}
