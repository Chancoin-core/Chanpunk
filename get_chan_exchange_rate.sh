#!/bin/bash
# 
# Trivial temporary workaround to get CHAN/USD exchange rate in native Bitpay JSON format for coinpunk.
#
# Yes, this is a very ugly and inneficient hack. Feel free to improve or rewrite in chanpunk directly.
#
# Add to Cron for the chanpunk user via "crontab -u chanpunk -e" to get new pricing every 15 mins
# 0,15,30,45 * * * * /path/to/get_chan_exchange_rate.sh >> /path/to/chanusd.log 2>&1
#
# 
# Edit your chanpunk config.json and change pricesUrl to http://localhost:8080/rates.json
#
#set -x

. /etc/profile

# Where to write stuff
TMPDIR=/tmp
OUTPUTFILE=/home/chanpunk/chanpunk/public/rates.json

PID=$$

# Functions
clean_up () {
	rm $TMPDIR/*.tmp.$PID
}

get_btc_rates () {
echo "Getting BTC Exchange Rates from Bitpay..."
curl -s -f --retry 5 "https://bitpay.com/api/rates" > $TMPDIR/rates.tmp.$PID
STATUS=$?
BTCRATES=`cat $TMPDIR/rates.tmp.$PID`
}

calc_btc_usd () {
echo "Isolating BTC Price..."
BTCUSD="`echo $BTCRATES | awk -F\} '{print $1}' | awk -F: '{print $4}'`"
BTCUSD=${BTCUSD//[[:space:]]/}
echo "Current BTC Value is \$$BTCUSD..."
}

get_chan_btc () {
echo "Getting Cryptsy CHAN-BTC Exchange Rate..."
#curl --retry 5 "http://pubapi.cryptsy.com/api.php?method=singlemarketdata\&marketid=151" > $TMPDIR/cryptsy.tmp.$PID
#cat $TMPDIR/cryptsy.tmp.$PID |  awk -F, '{print $4}'|awk -F\" '{print $4}' > $TMPDIR/chanbtc.tmp.$PID
# Single Order Data API seems to be marginally more reliable...
curl -s -f --retry 5 "http://pubapi.cryptsy.com/api.php?method=singleorderdata&marketid=151" > $TMPDIR/cryptsy.tmp.$PID
cat $TMPDIR/cryptsy.tmp.$PID | awk -F :\" '{print $8}'|cut -b 1-8 > $TMPDIR/chanbtc.tmp.$PID
CHANBTC=`cat $TMPDIR/chanbtc.tmp.$PID`
CHANBTC=${CHANBTC//[[:space:]]/}
}

output_chan_usd () {
echo "Current CHAN exchange rate is $CHANBTC BTC..."
echo "Converting CHAN-BTC to CHAN-USD..."
CHANUSD=$(echo "scale=4; $BTCUSD*$CHANBTC" | bc)
echo "Current CHAN value in USD is \$$CHANUSD"
echo "Writing CHAN/USD rate to local file..."
echo -n '[{"code":"USD","name":"US Dollar","rate":' > $OUTPUTFILE
echo -n $CHANUSD >> $OUTPUTFILE
echo "}]" >> $OUTPUTFILE
}

# Let's Go

# Get BTC Rates from BitPay
echo "Started $0 on `date +%c`"
get_btc_rates

if [[ ! -z "$BTCRATES" ]] ; then
	# Isolate USD value from API output
	calc_btc_usd
	# Get CHAN/BTC Rate from Cryptsy
	get_chan_btc
	if [[ ! -z "$CHANBTC" ]] ; then
		# Calcualte CHAN/USD
		output_chan_usd
	else
		echo "Cryptsy API appears to be down. Curl exited with status $STATUS..."
		clean_up
		echo "Unable to convert, please try again later."
		exit 1
	fi
else
	echo "Bitpay API appears to be down. Curl exited with status $STATUS..."
	clean_up
	echo "Unable to convert, please try again later."
	exit 1
fi

clean_up
echo "Finished!"
exit 0
