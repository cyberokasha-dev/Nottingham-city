extends RefCounted
# Authored dialogue; generated from tools/write_dialogue.py.
const LINES := {
  "street_muhammad_open": "Hi, I'm Muhammad. How's your day going?",
  "street_aisha_open": "Hello. Is everything all right around here?",
  "street_musa_open": "Hey, good to see someone out and about!",
  "street_jade_open": "Hello. What's happening in the neighbourhood?",
  "street_npc_0": "It's a quiet day. I'm walking to my next stop.",
  "street_npc_1": "I'm a little busy, but I can stop for a moment.",
  "street_npc_2": "Just getting some fresh air. What can I do for you?",
  "street_muhammad_reply_0": "Is there a good park nearby?",
  "street_aisha_reply_0": "Which way is the park?",
  "street_musa_reply_0": "Where can I find a nice place to relax?",
  "street_jade_reply_0": "Can you point me towards the park?",
  "street_npc_reply_0": "The east park is a good choice. I've marked it on your map.",
  "street_muhammad_reply_1": "I hope you have a good day.",
  "street_aisha_reply_1": "Thanks for stopping. Take care.",
  "street_musa_reply_1": "It was nice meeting you!",
  "street_jade_reply_1": "Thanks. Enjoy your walk.",
  "street_npc_reply_1": "Thank you. I'll remember that. Come and say hello again.",
  "street_muhammad_reply_2": "Move aside. I don't want trouble.",
  "street_aisha_reply_2": "You'd better stay out of my way.",
  "street_musa_reply_2": "Don't mess with me.",
  "street_jade_reply_2": "Keep your distance, or we'll have a problem.",
  "street_npc_reply_2": "Don't threaten me. Back off!",
  "park_muhammad_open": "This park looks peaceful. Do you come here often?",
  "park_aisha_open": "Is this a good place for a quiet break?",
  "park_musa_open": "Now this is a nice spot! How are you doing?",
  "park_jade_open": "I like the trees here. Is it usually this quiet?",
  "park_npc_0": "I like taking a walk here before going home.",
  "park_npc_1": "I stopped for a short break. It's quieter than the roads.",
  "park_npc_2": "It's a good place to relax and meet neighbours.",
  "park_muhammad_reply_0": "Would you like some company on your walk?",
  "park_aisha_reply_0": "Shall we walk a little together?",
  "park_musa_reply_0": "Come on, let's take a short walk together.",
  "park_jade_reply_0": "Would a little company be all right?",
  "park_npc_reply_0": "Sure. I'll walk beside you for a little while.",
  "park_muhammad_reply_1": "I'm going to take a break here.",
  "park_aisha_reply_1": "I need a quiet moment.",
  "park_musa_reply_1": "I'm taking it easy today.",
  "park_jade_reply_1": "I'll stay here and clear my head.",
  "park_npc_reply_1": "That's a good idea. Take your time and look after yourself.",
  "park_muhammad_reply_2": "Enjoy the park. I'll see you later.",
  "park_aisha_reply_2": "Thanks. I'll carry on now.",
  "park_musa_reply_2": "Have a good one. See you around!",
  "park_jade_reply_2": "Take care. Maybe we'll meet again.",
  "park_npc_reply_2": "See you later. Enjoy your day.",
  "car_muhammad_open": "Hello. I'm choosing a car for a drive.",
  "car_aisha_open": "Hello. Do you know these vehicles?",
  "car_musa_open": "These cars look good! Which one would you pick?",
  "car_jade_open": "Hello. Is the road clear for a drive?",
  "car_npc_0": "There are cars and trucks here. Drive carefully around people.",
  "car_npc_1": "The road looks clear, but check before you pull out.",
  "car_npc_2": "I like the gold car. It's easy to spot from here.",
  "car_muhammad_reply_0": "I'll watch out for pedestrians.",
  "car_aisha_reply_0": "I'll keep the speed down around people.",
  "car_musa_reply_0": "Don't worry. I'll take it slowly.",
  "car_jade_reply_0": "I'll check the road before I go.",
  "car_npc_reply_0": "Thanks. That makes it safer for everyone.",
  "car_muhammad_reply_1": "Are there taxis or buses here yet?",
  "car_aisha_reply_1": "Is public transport running?",
  "car_musa_reply_1": "Can I catch a bus or a taxi?",
  "car_jade_reply_1": "Is there a way to get a ride around the city?",
  "car_npc_reply_1": "Not yet. For now we walk or you drive. Buses and taxis will come later.",
  "car_muhammad_reply_2": "I'll be the fastest driver here.",
  "car_aisha_reply_2": "Nobody is going to slow me down.",
  "car_musa_reply_2": "Watch me race down that road!",
  "car_jade_reply_2": "I want to see how fast this car can go.",
  "car_npc_reply_2": "Please don't race near people. I'm keeping my distance.",
  "house_muhammad_open": "Hello. It's good to be indoors. How are you?",
  "house_aisha_open": "Hello. Is this a good time to visit?",
  "house_musa_open": "This home feels comfortable. How's it going?",
  "house_jade_open": "Hello. I hope I'm not disturbing you.",
  "house_npc_0": "Make yourself comfortable. There's a sofa and a bed.",
  "house_npc_1": "I was having a quiet moment at home.",
  "house_npc_2": "Welcome. Let's keep things peaceful in here.",
  "house_muhammad_reply_0": "Where can I sit or have a rest?",
  "house_aisha_reply_0": "Is there somewhere I can sit?",
  "house_musa_reply_0": "I'd like to relax for a moment.",
  "house_jade_reply_0": "Can I take a quiet break here?",
  "house_npc_reply_0": "Walk beside the sofa to sit, or beside the bed to sleep. Press E to use it.",
  "house_muhammad_reply_1": "Thank you for welcoming me.",
  "house_aisha_reply_1": "Thanks. I appreciate it.",
  "house_musa_reply_1": "That's kind of you. Thank you!",
  "house_jade_reply_1": "Thank you. I'll be considerate.",
  "house_npc_reply_1": "You're welcome. It's nice to have a friendly visitor.",
  "house_muhammad_reply_2": "I'll let you get some rest.",
  "house_aisha_reply_2": "I'll leave you in peace now.",
  "house_musa_reply_2": "See you later. Enjoy your quiet time.",
  "house_jade_reply_2": "I'll go now. Take care.",
  "house_npc_reply_2": "Take care. Use the front door when you're ready to leave.",
  "injured_muhammad_open": "You look hurt. Are you all right?",
  "injured_aisha_open": "Are you injured? Do you need a break?",
  "injured_musa_open": "That looked painful. Are you okay?",
  "injured_jade_open": "You don't look well. Can I help?",
  "injured_npc_0": "I'm hurt. I need to take things slowly.",
  "injured_npc_1": "My health is low. I could do with some peace.",
  "injured_npc_2": "I need to recover before I carry on.",
  "injured_muhammad_reply_0": "Take your time. I won't bother you.",
  "injured_aisha_reply_0": "Rest for a moment. You're safe.",
  "injured_musa_reply_0": "Easy now. Have a quiet break.",
  "injured_jade_reply_0": "Take a breath. I won't start any trouble.",
  "injured_npc_reply_0": "Thank you. I'll calm down and take a rest.",
  "injured_muhammad_reply_1": "I'm sorry if I caused that. Let's stop fighting.",
  "injured_aisha_reply_1": "I'm sorry. I don't want to hurt you.",
  "injured_musa_reply_1": "Sorry about that. Let's call it a day.",
  "injured_jade_reply_1": "I was wrong to cause trouble. I'm sorry.",
  "injured_npc_reply_1": "I accept your apology. Let's leave the fighting behind us.",
  "injured_muhammad_reply_2": "You're not so tough now, are you?",
  "injured_aisha_reply_2": "You should have stayed out of my way.",
  "injured_musa_reply_2": "Can't take a little fight?",
  "injured_jade_reply_2": "You're only slowing everyone down.",
  "injured_npc_reply_2": "That's enough. Leave me alone!",
  "hostile_muhammad_open": "Wait. Can we talk instead of fighting?",
  "hostile_aisha_open": "Stop a moment. I want to talk.",
  "hostile_musa_open": "Hold on. Let's sort this out.",
  "hostile_jade_open": "Wait. This isn't helping either of us.",
  "hostile_npc_0": "You started trouble. What do you want now?",
  "hostile_npc_1": "I'm angry. Give me a good reason to stop.",
  "hostile_npc_2": "You need to explain yourself.",
  "hostile_muhammad_reply_0": "I'm sorry. I won't hit you again.",
  "hostile_aisha_reply_0": "I was wrong. Let's stop now.",
  "hostile_musa_reply_0": "Sorry. I got carried away.",
  "hostile_jade_reply_0": "I'm sorry. I'd rather make peace.",
  "hostile_npc_reply_0": "All right. I accept your apology. Let's both calm down.",
  "hostile_muhammad_reply_1": "I'll walk away. No more trouble.",
  "hostile_aisha_reply_1": "I'm leaving. Let's stop here.",
  "hostile_musa_reply_1": "I'll give you some space.",
  "hostile_jade_reply_1": "I'll go. We don't need another fight.",
  "hostile_npc_reply_1": "Fine. Keep your distance and we'll leave it there.",
  "hostile_muhammad_reply_2": "I'm not backing down.",
  "hostile_aisha_reply_2": "You haven't heard the last of this.",
  "hostile_musa_reply_2": "Come on then. I'm still here.",
  "hostile_jade_reply_2": "I won't let you push me around.",
  "hostile_npc_reply_2": "Then stay back. I'm ready to defend myself.",
  "friend_muhammad_open": "Hello again! It's good to see you.",
  "friend_aisha_open": "Hello again. How have you been?",
  "friend_musa_open": "There's a friendly face! How's your day?",
  "friend_jade_open": "Hello again. It's nice to meet you here.",
  "friend_npc_0": "Good to see you too. I remember you being kind.",
  "friend_npc_1": "Hello, my friend. I'm glad we met again.",
  "friend_npc_2": "It's nice seeing a familiar, friendly face.",
  "friend_muhammad_reply_0": "Would you like to walk with me?",
  "friend_aisha_reply_0": "Do you want some company?",
  "friend_musa_reply_0": "Come along for a short walk with me!",
  "friend_jade_reply_0": "Would you like to join me for a little while?",
  "friend_npc_reply_0": "I'd like that. I'll stay nearby for a short walk.",
  "friend_muhammad_reply_1": "Could you help me find the east park?",
  "friend_aisha_reply_1": "Which way should I go for the east park?",
  "friend_musa_reply_1": "Remind me where the east park is?",
  "friend_jade_reply_1": "Can you point me towards the east park?",
  "friend_npc_reply_1": "Of course. I've marked the park on your map.",
  "friend_muhammad_reply_2": "Take care. I'll see you around.",
  "friend_aisha_reply_2": "Thanks. See you later.",
  "friend_musa_reply_2": "Have a good day, my friend!",
  "friend_jade_reply_2": "Take care. I'm glad we caught up.",
  "friend_npc_reply_2": "See you later, my friend.",
  "event_muhammad_enter_car": "Let's take a drive.",
  "event_aisha_enter_car": "I'll check the road before I go.",
  "event_musa_enter_car": "Time for a drive!",
  "event_jade_enter_car": "Let's see where this road goes.",
  "event_muhammad_exit_car": "I'll carry on on foot.",
  "event_aisha_exit_car": "Stopped safely. I'll get out now.",
  "event_musa_exit_car": "That was a good drive.",
  "event_jade_exit_car": "I'll explore on foot from here.",
  "event_muhammad_enter_house": "Let's have a look inside.",
  "event_aisha_enter_house": "Hello? I'm coming in.",
  "event_musa_enter_house": "It's good to be indoors.",
  "event_jade_enter_house": "A quiet home. Let's take a look.",
  "event_muhammad_exit_house": "Back out into the city.",
  "event_aisha_exit_house": "I'll close the door behind me.",
  "event_musa_exit_house": "Time to get moving again!",
  "event_jade_exit_house": "I'll head back outside now.",
  "event_muhammad_sit": "I'll sit here for a moment.",
  "event_aisha_sit": "A short break will help.",
  "event_musa_sit": "This looks like a comfortable seat.",
  "event_jade_sit": "I'll sit and think for a moment.",
  "event_muhammad_sleep": "I need some sleep. See you in a little while.",
  "event_aisha_sleep": "Time to rest and recover.",
  "event_musa_sleep": "I'll have a little sleep.",
  "event_jade_sleep": "I'll get some rest now.",
  "event_muhammad_wake": "I'm awake. Let's get going.",
  "event_aisha_wake": "Rested and ready.",
  "event_musa_wake": "That helped! Let's go.",
  "event_jade_wake": "I'm ready to carry on now.",
  "event_muhammad_switch": "I'm Muhammad. Let's explore the city.",
  "event_aisha_switch": "Aisha here. What's the plan?",
  "event_musa_switch": "Musa here. Ready when you are!",
  "event_jade_switch": "Jade here. Let's see what's happening.",
  "event_muhammad_fold": "I'll stand here for a moment.",
  "event_aisha_fold": "I'll wait here.",
  "event_musa_fold": "I'll take a moment.",
  "event_jade_fold": "Just a quiet moment."
}
const SCENES := {
  "street": {
    "openers": {
      "Muhammad": "street_muhammad_open",
      "Aisha": "street_aisha_open",
      "Musa": "street_musa_open",
      "Jade": "street_jade_open"
    },
    "npc": [
      "street_npc_0",
      "street_npc_1",
      "street_npc_2"
    ],
    "options": [
      {
        "label": "Ask about the park",
        "effect": "directions",
        "player": {
          "Muhammad": "street_muhammad_reply_0",
          "Aisha": "street_aisha_reply_0",
          "Musa": "street_musa_reply_0",
          "Jade": "street_jade_reply_0"
        },
        "npc": "street_npc_reply_0"
      },
      {
        "label": "Be friendly",
        "effect": "friend",
        "player": {
          "Muhammad": "street_muhammad_reply_1",
          "Aisha": "street_aisha_reply_1",
          "Musa": "street_musa_reply_1",
          "Jade": "street_jade_reply_1"
        },
        "npc": "street_npc_reply_1"
      },
      {
        "label": "Threaten them",
        "effect": "threat",
        "player": {
          "Muhammad": "street_muhammad_reply_2",
          "Aisha": "street_aisha_reply_2",
          "Musa": "street_musa_reply_2",
          "Jade": "street_jade_reply_2"
        },
        "npc": "street_npc_reply_2"
      }
    ]
  },
  "park": {
    "openers": {
      "Muhammad": "park_muhammad_open",
      "Aisha": "park_aisha_open",
      "Musa": "park_musa_open",
      "Jade": "park_jade_open"
    },
    "npc": [
      "park_npc_0",
      "park_npc_1",
      "park_npc_2"
    ],
    "options": [
      {
        "label": "Ask to walk together",
        "effect": "follow",
        "player": {
          "Muhammad": "park_muhammad_reply_0",
          "Aisha": "park_aisha_reply_0",
          "Musa": "park_musa_reply_0",
          "Jade": "park_jade_reply_0"
        },
        "npc": "park_npc_reply_0"
      },
      {
        "label": "Say you need a rest",
        "effect": "friend",
        "player": {
          "Muhammad": "park_muhammad_reply_1",
          "Aisha": "park_aisha_reply_1",
          "Musa": "park_musa_reply_1",
          "Jade": "park_jade_reply_1"
        },
        "npc": "park_npc_reply_1"
      },
      {
        "label": "Leave politely",
        "effect": "leave",
        "player": {
          "Muhammad": "park_muhammad_reply_2",
          "Aisha": "park_aisha_reply_2",
          "Musa": "park_musa_reply_2",
          "Jade": "park_jade_reply_2"
        },
        "npc": "park_npc_reply_2"
      }
    ]
  },
  "car": {
    "openers": {
      "Muhammad": "car_muhammad_open",
      "Aisha": "car_aisha_open",
      "Musa": "car_musa_open",
      "Jade": "car_jade_open"
    },
    "npc": [
      "car_npc_0",
      "car_npc_1",
      "car_npc_2"
    ],
    "options": [
      {
        "label": "Promise to drive safely",
        "effect": "friend",
        "player": {
          "Muhammad": "car_muhammad_reply_0",
          "Aisha": "car_aisha_reply_0",
          "Musa": "car_musa_reply_0",
          "Jade": "car_jade_reply_0"
        },
        "npc": "car_npc_reply_0"
      },
      {
        "label": "Ask about taxis",
        "effect": "info",
        "player": {
          "Muhammad": "car_muhammad_reply_1",
          "Aisha": "car_aisha_reply_1",
          "Musa": "car_musa_reply_1",
          "Jade": "car_jade_reply_1"
        },
        "npc": "car_npc_reply_1"
      },
      {
        "label": "Boast about speeding",
        "effect": "avoid",
        "player": {
          "Muhammad": "car_muhammad_reply_2",
          "Aisha": "car_aisha_reply_2",
          "Musa": "car_musa_reply_2",
          "Jade": "car_jade_reply_2"
        },
        "npc": "car_npc_reply_2"
      }
    ]
  },
  "house": {
    "openers": {
      "Muhammad": "house_muhammad_open",
      "Aisha": "house_aisha_open",
      "Musa": "house_musa_open",
      "Jade": "house_jade_open"
    },
    "npc": [
      "house_npc_0",
      "house_npc_1",
      "house_npc_2"
    ],
    "options": [
      {
        "label": "Ask about resting",
        "effect": "info",
        "player": {
          "Muhammad": "house_muhammad_reply_0",
          "Aisha": "house_aisha_reply_0",
          "Musa": "house_musa_reply_0",
          "Jade": "house_jade_reply_0"
        },
        "npc": "house_npc_reply_0"
      },
      {
        "label": "Thank your host",
        "effect": "friend",
        "player": {
          "Muhammad": "house_muhammad_reply_1",
          "Aisha": "house_aisha_reply_1",
          "Musa": "house_musa_reply_1",
          "Jade": "house_jade_reply_1"
        },
        "npc": "house_npc_reply_1"
      },
      {
        "label": "Leave the conversation",
        "effect": "leave",
        "player": {
          "Muhammad": "house_muhammad_reply_2",
          "Aisha": "house_aisha_reply_2",
          "Musa": "house_musa_reply_2",
          "Jade": "house_jade_reply_2"
        },
        "npc": "house_npc_reply_2"
      }
    ]
  },
  "injured": {
    "openers": {
      "Muhammad": "injured_muhammad_open",
      "Aisha": "injured_aisha_open",
      "Musa": "injured_musa_open",
      "Jade": "injured_jade_open"
    },
    "npc": [
      "injured_npc_0",
      "injured_npc_1",
      "injured_npc_2"
    ],
    "options": [
      {
        "label": "Offer reassurance",
        "effect": "peace",
        "player": {
          "Muhammad": "injured_muhammad_reply_0",
          "Aisha": "injured_aisha_reply_0",
          "Musa": "injured_musa_reply_0",
          "Jade": "injured_jade_reply_0"
        },
        "npc": "injured_npc_reply_0"
      },
      {
        "label": "Apologise",
        "effect": "peace",
        "player": {
          "Muhammad": "injured_muhammad_reply_1",
          "Aisha": "injured_aisha_reply_1",
          "Musa": "injured_musa_reply_1",
          "Jade": "injured_jade_reply_1"
        },
        "npc": "injured_npc_reply_1"
      },
      {
        "label": "Mock them",
        "effect": "threat",
        "player": {
          "Muhammad": "injured_muhammad_reply_2",
          "Aisha": "injured_aisha_reply_2",
          "Musa": "injured_musa_reply_2",
          "Jade": "injured_jade_reply_2"
        },
        "npc": "injured_npc_reply_2"
      }
    ]
  },
  "hostile": {
    "openers": {
      "Muhammad": "hostile_muhammad_open",
      "Aisha": "hostile_aisha_open",
      "Musa": "hostile_musa_open",
      "Jade": "hostile_jade_open"
    },
    "npc": [
      "hostile_npc_0",
      "hostile_npc_1",
      "hostile_npc_2"
    ],
    "options": [
      {
        "label": "Apologise and make peace",
        "effect": "peace",
        "player": {
          "Muhammad": "hostile_muhammad_reply_0",
          "Aisha": "hostile_aisha_reply_0",
          "Musa": "hostile_musa_reply_0",
          "Jade": "hostile_jade_reply_0"
        },
        "npc": "hostile_npc_reply_0"
      },
      {
        "label": "Leave without arguing",
        "effect": "avoid",
        "player": {
          "Muhammad": "hostile_muhammad_reply_1",
          "Aisha": "hostile_aisha_reply_1",
          "Musa": "hostile_musa_reply_1",
          "Jade": "hostile_jade_reply_1"
        },
        "npc": "hostile_npc_reply_1"
      },
      {
        "label": "Continue the argument",
        "effect": "threat",
        "player": {
          "Muhammad": "hostile_muhammad_reply_2",
          "Aisha": "hostile_aisha_reply_2",
          "Musa": "hostile_musa_reply_2",
          "Jade": "hostile_jade_reply_2"
        },
        "npc": "hostile_npc_reply_2"
      }
    ]
  },
  "friend": {
    "openers": {
      "Muhammad": "friend_muhammad_open",
      "Aisha": "friend_aisha_open",
      "Musa": "friend_musa_open",
      "Jade": "friend_jade_open"
    },
    "npc": [
      "friend_npc_0",
      "friend_npc_1",
      "friend_npc_2"
    ],
    "options": [
      {
        "label": "Invite them along",
        "effect": "follow",
        "player": {
          "Muhammad": "friend_muhammad_reply_0",
          "Aisha": "friend_aisha_reply_0",
          "Musa": "friend_musa_reply_0",
          "Jade": "friend_jade_reply_0"
        },
        "npc": "friend_npc_reply_0"
      },
      {
        "label": "Ask for directions",
        "effect": "directions",
        "player": {
          "Muhammad": "friend_muhammad_reply_1",
          "Aisha": "friend_aisha_reply_1",
          "Musa": "friend_musa_reply_1",
          "Jade": "friend_jade_reply_1"
        },
        "npc": "friend_npc_reply_1"
      },
      {
        "label": "Say goodbye",
        "effect": "leave",
        "player": {
          "Muhammad": "friend_muhammad_reply_2",
          "Aisha": "friend_aisha_reply_2",
          "Musa": "friend_musa_reply_2",
          "Jade": "friend_jade_reply_2"
        },
        "npc": "friend_npc_reply_2"
      }
    ]
  }
}
