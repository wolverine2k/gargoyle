#!/usr/bin/haserl
<?
	# This program is copyright © 2008-2011 Eric Bishop and is distributed under the terms of the GNU GPL
	# version 2.0 with a special clarification/exception that permits adapting the program to
	# configure proprietary "back end" software provided that all modifications to the web interface
	# itself remain covered by the GPL.
	# See http://gargoyle-router.com/faq.html#qfoss for more information
	eval $( gargoyle_session_validator -c "$POST_hash" -e "$COOKIE_exp" -a "$HTTP_USER_AGENT" -i "$REMOTE_ADDR" -r "login.sh" -t $(uci get gargoyle.global.session_timeout) -b "$COOKIE_browser_time"  )
	echo "Content-type: text/plain"
	echo ""

	scan_brcm()
	{
		if_exists=$(ifconfig | grep wl0)
		is_disabled=$(uci get wireless.wl0.disabled)
		if [ -z "$if_exists" ] || [ "$is_disabled" = 1 ] ; then
			wl up
			ifconfig wl0 up
		fi
		sleep 4

		iwinfo wl0 scan
		if [ -z "$if_exists" ] ; then
			ifconfig wl0 down
		fi
	}

	scan_mac80211()
	{
		radio_disabled1=$(uci get wireless.@wifi-device[0].disabled 2>/dev/null)
		radio_disabled2=$(uci get wireless.@wifi-device[1].disabled 2>/dev/null)
		g_sta=""
		a_sta=""
		iflist=$(iwinfo | awk '$0 ~ /^[a-z]/ { print $1 ; }' )
		for i in $iflist ; do
			i_info=$( iwinfo "$i" info 2>/dev/null )
			is_sta=$( printf "$i_info\n" | grep "Mode: *Client" )
			if [ -n "$is_sta" ] ; then
				is_g=$(   printf "$i_info\n" | egrep "802.11((b)|(bg)|(g)|(gn)|(bgn))" )
				is_a=$(   printf "$i_info\n" | egrep "802.11((a)|(an)|(anac)|(nac)|(ac))" )
				if [ -n "$is_g" ] ; then
					g_sta="$i"
				elif [ -n "$is_a" ] ; then
					a_sta="$i"
				fi
			fi
		done	


		test_ifs="$g_sta"
		if [ -z "$g_sta" ] || [ "$radio_disabled1" = "1" ] || [ "$radio_disabled2" = "1" ]  ; then
			g_sta=""
			test_ifs="phy0"
		fi

		if [ `uci show wireless | grep wifi-device | wc -l`"" = "2" ] && [ -e "/sys/class/ieee80211/phy1" ] && [ ! `uci get wireless.@wifi-device[0].hwmode`"" = `uci get wireless.@wifi-device[1].hwmode`""  ] ; then
			phy0_is_g=$(iw phy0 info | grep "2[0-9]\{3\} MHz \[[0-9]\{1,3\}\]")
			g_phy="phy0"
			a_phy="phy1"
			if [ -z "$phy0_is_g" ] ; then
				g_phy="phy1"
				a_phy="phy0"
			fi
			if [ -z "$g_sta" ] ; then
				test_ifs="$g_phy"
			fi
			if [ -z "$a_sta" ] || [ "$radio_disabled1" = "1" ] || [ "$radio_disabled2" = "1" ] ; then
				test_ifs="$test_ifs $a_phy"
			else
				test_ifs="$test_ifs $a_sta"
			fi
		fi

		for if in $test_ifs ; do
			iwinfo "$if" scan
		done

	}

	if [ -e "/lib/wifi/broadcom.sh" ] ; then
		scan_brcm
	elif [ -e "/lib/wifi/mac80211.sh" ] ; then
		scan_mac80211
	fi

?>
