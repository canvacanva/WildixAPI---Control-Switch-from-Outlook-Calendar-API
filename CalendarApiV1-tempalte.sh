#!/bin/bash
# V1 - Monitora il calendario di un singolo utente outlook definito e cambia lo stato di un singolo interruttore
# necessaria installazione di jq su Linux
##############
# TENANT AZURE: sul tenant Azure deve essere stata registrata una APP , es Calendar API Reader
# TENANT AZURE: URL di reindirizzamento: https://login.microsoftonline.com/common/oauth2/nativeclient & http://localhost
# TENANT AZURE: Creare un Client Secret, segnarsi ClientID e ClientSec
# TANANT AZURE: Autorizzazioni per Microsoft Graph di tipo Appliczione e Delagato per: Application.Read.All/Calendars.Read/User.Read.All - Concedere Accesso Amministrativo
###############
##### USO######
# ./location/sctipt.sh email@dominio NumeroSwitchID
# email@dominio è l'utente o la casella di cui monitorare il calendario
# SwitchID è il numero dello switch da comandare su Wildix
##############
#WILDIX CONF: Custom APP: set(user=email@dominio)
#WILDIX CONF: Custom APP: set(switchID=NumeroSwitchId)
#WILDIX CONF: Custom APP: System(/home/admin/localscripts/CalendarApi.sh ${user} ${switchID} )
#WILDIX CONF: Gestire Go To in base allo stato dello switch
#WILDIX CONF: Il nome dello switch prendeil nome definito nella variabile SwitchNameFix

#Editare con i dati del centralino
APIuser='a'
APIpwd='b'
PBX='c'
SwitchNameFix='ApiSwitch'
SwitchID=$2
###############
# Settare le variabili ottenute creando la APP su Tenant
TenantID='Tid'
ClientID='Cid'
ClientSec='Csec'
User=$1
###############
# URL per le API
URLGetToken='https://login.microsoftonline.com/'$TenantID'/oauth2/v2.0/token'
URLUserCalendar='https://graph.microsoft.com/v1.0/users/'$User'/calendar/events'
###############

#Ottengo token di autenticazione, di durata 3600 secondi standard
AccessToken=$(curl -s --location --request POST $URLGetToken --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'client_id='$ClientID --data-urlencode 'scope=https://graph.microsoft.com/.default' --data-urlencode 'client_secret='$ClientSec --data-urlencode 'grant_type=client_credentials'  | jq -r '.access_token')
#echo $AccessToken
APIEvent=$(curl -s --location --request GET $URLUserCalendar --header 'Authorization: Bearer '$AccessToken --data '')
#echo $APIEvent | jq

##############
# Verifica se presenrte un errore di autenticazione
Error=$(echo $APIEvent | jq -r '.error | .code' )

if [ $Error = null  ]
then
	if [ $SwitchID == 5 ]
	then
		SwitchName=$SwitchNameFix
	fi

	# Nessun Errore
	# Nome Evento
	EventName=$(echo $APIEvent | jq -r '.value[0] | .subject' | sed -e 's/[{}"]//g' -e 's/: //g')
	# Inizio Evento
	EventStart=$(echo $APIEvent | jq -r '.value[0].start | .dateTime' | sed -e 's/[{}"]//g' -e 's/: //g')
	# Fine Evento
	EventEnd=$(echo $APIEvent | jq -r '.value[0].end | .dateTime' | sed -e 's/[{}"]//g' -e 's/: //g')
	# echo $EventName
	# echo $EventStart
	# echo $EventEnd

	# Verifica se è presente un evento èd è in corso
	start=$(date +%s -d $EventStart)
	finish=$(date +%s -d $EventEnd)
	now=$(date +%s)

	if [ $now -ge $start ] && [ $now -lt $finish ]
	then
		#echo "Evento in corso:" $EventName
		curl -s -u $APIuser:$APIpwd -d "title="$SwitchName"&state=1" -H "Content-Type: application/x-www-form-urlencoded" -X PUT 'https://'$PBX'.wildixin.com/api/v1/Dialplan/Switches/'$SwitchID'/' | jq

	else
		#echo "Nessun Evento"
		curl -s -u $APIuser:$APIpwd -d "title="$SwitchName"&state=0" -H "Content-Type: application/x-www-form-urlencoded" -X PUT 'https://'$PBX'.wildixin.com/api/v1/Dialplan/Switches/'$SwitchID'/' | jq
	fi

else
#echo $Error
	exit
fi
