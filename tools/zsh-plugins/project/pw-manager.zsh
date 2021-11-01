
function pw-manager-session() {
  op-session.sh
}

function pw-manager-session-renew() {
  op-renew-session.sh
}

function pw-manager-otp() {
  op-otp-token.sh $1
}
