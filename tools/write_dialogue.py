"""Author the bounded scene dialogue and per-protagonist responses. No runtime AI service."""
import json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
people=['Muhammad','Aisha','Musa','Jade'];lines={};scenes={}
data={
'street':([
"Hi, I'm Muhammad. How's your day going?","Hello. Is everything all right around here?","Hey, good to see someone out and about!","Hello. What's happening in the neighbourhood?"],
["It's a quiet day. I'm walking to my next stop.","I'm a little busy, but I can stop for a moment.","Just getting some fresh air. What can I do for you?"],
[("Ask about the park",["Is there a good park nearby?","Which way is the park?","Where can I find a nice place to relax?","Can you point me towards the park?"],"The east park is a good choice. I've marked it on your map.",'directions'),
("Be friendly",["I hope you have a good day.","Thanks for stopping. Take care.","It was nice meeting you!","Thanks. Enjoy your walk."],"Thank you. I'll remember that. Come and say hello again.",'friend'),
("Threaten them",["Move aside. I don't want trouble.","You'd better stay out of my way.","Don't mess with me.","Keep your distance, or we'll have a problem."],"Don't threaten me. Back off!",'threat')]),
'park':([
"This park looks peaceful. Do you come here often?","Is this a good place for a quiet break?","Now this is a nice spot! How are you doing?","I like the trees here. Is it usually this quiet?"],
["I like taking a walk here before going home.","I stopped for a short break. It's quieter than the roads.","It's a good place to relax and meet neighbours."],
[("Ask to walk together",["Would you like some company on your walk?","Shall we walk a little together?","Come on, let's take a short walk together.","Would a little company be all right?"],"Sure. I'll walk beside you for a little while.",'follow'),
("Say you need a rest",["I'm going to take a break here.","I need a quiet moment.","I'm taking it easy today.","I'll stay here and clear my head."],"That's a good idea. Take your time and look after yourself.",'friend'),
("Leave politely",["Enjoy the park. I'll see you later.","Thanks. I'll carry on now.","Have a good one. See you around!","Take care. Maybe we'll meet again."],"See you later. Enjoy your day.",'leave')]),
'car':([
"Hello. I'm choosing a car for a drive.","Hello. Do you know these vehicles?","These cars look good! Which one would you pick?","Hello. Is the road clear for a drive?"],
["There are cars and trucks here. Drive carefully around people.","The road looks clear, but check before you pull out.","I like the gold car. It's easy to spot from here."],
[("Promise to drive safely",["I'll watch out for pedestrians.","I'll keep the speed down around people.","Don't worry. I'll take it slowly.","I'll check the road before I go."],"Thanks. That makes it safer for everyone.",'friend'),
("Ask about taxis",["Are there taxis or buses here yet?","Is public transport running?","Can I catch a bus or a taxi?","Is there a way to get a ride around the city?"],"Not yet. For now we walk or you drive. Buses and taxis will come later.",'info'),
("Boast about speeding",["I'll be the fastest driver here.","Nobody is going to slow me down.","Watch me race down that road!","I want to see how fast this car can go."],"Please don't race near people. I'm keeping my distance.",'avoid')]),
'house':([
"Hello. It's good to be indoors. How are you?","Hello. Is this a good time to visit?","This home feels comfortable. How's it going?","Hello. I hope I'm not disturbing you."],
["Make yourself comfortable. There's a sofa and a bed.","I was having a quiet moment at home.","Welcome. Let's keep things peaceful in here."],
[("Ask about resting",["Where can I sit or have a rest?","Is there somewhere I can sit?","I'd like to relax for a moment.","Can I take a quiet break here?"],"Walk beside the sofa to sit, or beside the bed to sleep. Press E to use it.",'info'),
("Thank your host",["Thank you for welcoming me.","Thanks. I appreciate it.","That's kind of you. Thank you!","Thank you. I'll be considerate."],"You're welcome. It's nice to have a friendly visitor.",'friend'),
("Leave the conversation",["I'll let you get some rest.","I'll leave you in peace now.","See you later. Enjoy your quiet time.","I'll go now. Take care."],"Take care. Use the front door when you're ready to leave.",'leave')]),
'injured':([
"You look hurt. Are you all right?","Are you injured? Do you need a break?","That looked painful. Are you okay?","You don't look well. Can I help?"],
["I'm hurt. I need to take things slowly.","My health is low. I could do with some peace.","I need to recover before I carry on."],
[("Offer reassurance",["Take your time. I won't bother you.","Rest for a moment. You're safe.","Easy now. Have a quiet break.","Take a breath. I won't start any trouble."],"Thank you. I'll calm down and take a rest.",'peace'),
("Apologise",["I'm sorry if I caused that. Let's stop fighting.","I'm sorry. I don't want to hurt you.","Sorry about that. Let's call it a day.","I was wrong to cause trouble. I'm sorry."],"I accept your apology. Let's leave the fighting behind us.",'peace'),
("Mock them",["You're not so tough now, are you?","You should have stayed out of my way.","Can't take a little fight?","You're only slowing everyone down."],"That's enough. Leave me alone!",'threat')]),
'hostile':([
"Wait. Can we talk instead of fighting?","Stop a moment. I want to talk.","Hold on. Let's sort this out.","Wait. This isn't helping either of us."],
["You started trouble. What do you want now?","I'm angry. Give me a good reason to stop.","You need to explain yourself."],
[("Apologise and make peace",["I'm sorry. I won't hit you again.","I was wrong. Let's stop now.","Sorry. I got carried away.","I'm sorry. I'd rather make peace."],"All right. I accept your apology. Let's both calm down.",'peace'),
("Leave without arguing",["I'll walk away. No more trouble.","I'm leaving. Let's stop here.","I'll give you some space.","I'll go. We don't need another fight."],"Fine. Keep your distance and we'll leave it there.",'avoid'),
("Continue the argument",["I'm not backing down.","You haven't heard the last of this.","Come on then. I'm still here.","I won't let you push me around."],"Then stay back. I'm ready to defend myself.",'threat')]),
'friend':([
"Hello again! It's good to see you.","Hello again. How have you been?","There's a friendly face! How's your day?","Hello again. It's nice to meet you here."],
["Good to see you too. I remember you being kind.","Hello, my friend. I'm glad we met again.","It's nice seeing a familiar, friendly face."],
[("Invite them along",["Would you like to walk with me?","Do you want some company?","Come along for a short walk with me!","Would you like to join me for a little while?"],"I'd like that. I'll stay nearby for a short walk.",'follow'),
("Ask for directions",["Could you help me find the east park?","Which way should I go for the east park?","Remind me where the east park is?","Can you point me towards the east park?"],"Of course. I've marked the park on your map.",'directions'),
("Say goodbye",["Take care. I'll see you around.","Thanks. See you later.","Have a good day, my friend!","Take care. I'm glad we caught up."],"See you later, my friend.",'leave')])
}
for scene,(openings,npc,options) in data.items():
 entry={'openers':{},'npc':[],'options':[]}
 for person,text in zip(people,openings):
  key=scene+'_'+person.lower()+'_open';lines[key]=text;entry['openers'][person]=key
 for i,text in enumerate(npc):key=scene+'_npc_'+str(i);lines[key]=text;entry['npc'].append(key)
 for i,(label,spoken,reply,effect) in enumerate(options):
  choice={'label':label,'effect':effect,'player':{}}
  for person,text in zip(people,spoken):
   key=scene+'_'+person.lower()+'_reply_'+str(i);lines[key]=text;choice['player'][person]=key
  key=scene+'_npc_reply_'+str(i);lines[key]=reply;choice['npc']=key;entry['options'].append(choice)
 scenes[scene]=entry
# Short character-specific reactions to the existing world actions.
events={
'enter_car':["Let's take a drive.","I'll check the road before I go.","Time for a drive!","Let's see where this road goes."],
'exit_car':["I'll carry on on foot.","Stopped safely. I'll get out now.","That was a good drive.","I'll explore on foot from here."],
'enter_house':["Let's have a look inside.","Hello? I'm coming in.","It's good to be indoors.","A quiet home. Let's take a look."],
'exit_house':["Back out into the city.","I'll close the door behind me.","Time to get moving again!","I'll head back outside now."],
'sit':["I'll sit here for a moment.","A short break will help.","This looks like a comfortable seat.","I'll sit and think for a moment."],
'sleep':["I need some sleep. See you in a little while.","Time to rest and recover.","I'll have a little sleep.","I'll get some rest now."],
'wake':["I'm awake. Let's get going.","Rested and ready.","That helped! Let's go.","I'm ready to carry on now."],
'switch':["I'm Muhammad. Let's explore the city.","Aisha here. What's the plan?","Musa here. Ready when you are!","Jade here. Let's see what's happening."],
'fold':["I'll stand here for a moment.","I'll wait here.","I'll take a moment.","Just a quiet moment."]}
for event,spoken in events.items():
 for person,text in zip(people,spoken):lines['event_'+person.lower()+'_'+event]=text
(ROOT/'actors/dialogue_data.gd').write_text('extends RefCounted\n# Authored dialogue; generated from tools/write_dialogue.py.\nconst LINES := '+json.dumps(lines,indent=2)+'\nconst SCENES := '+json.dumps(scenes,indent=2)+'\n')
(ROOT/'actors/voices/dialogue-source.json').write_text(json.dumps(lines,indent=2)+'\n')
print(len(scenes),'contexts;',len(lines),'character and NPC lines')
