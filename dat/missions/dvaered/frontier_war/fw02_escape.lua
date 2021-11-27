--[[
<?xml version='1.0' encoding='utf8'?>
<mission name="Dvaered Escape">
 <flags>
  <unique />
 </flags>
 <avail>
  <priority>2</priority>
  <chance>10</chance>
  <done>Dvaered Sabotage</done>
  <location>Bar</location>
  <cond>var.peek("loyal2klank") == true</cond>
  <faction>Dvaered</faction>
 </avail>
 <notes>
  <campaign>Frontier Invasion</campaign>
  <done_evt name="Betray General Klank">If you don't betray</done_evt>
  <provides name="General Klank wants his 10M back">If you get into debt</provides>
 </notes>
</mission>
--]]
--[[
-- Dvaered Escape
-- This is the third mission of the Frontier War Dvaered campaign.
-- The player has to set up the evasion of a Goddard executive.
-- This executive will then help House Dvaered on the diplomatic point of view.

   Stages :
   0) Goto find Hamfresser
   1) Goto the interception
   2) Start to run away
   3) Goto an hospital
   4) Runaway
   5) Player has been hailed by Captain HewHew
   6) Player has met the Empire and Pirate agent, but did not accept any of their offers
   7) Accepted Empire solution: can cross blockade of Alteris->Goddard
   8) Accepted Pirate solution: can cross any blockade
   9) Accepted Pirate solution: can cross any blockade, but has paid cash
--]]
local lmisn = require "lmisn"
require "proximity"
local portrait = require "portrait"
local fw = require "common.frontier_war"
local fmt = require "format"
local pir = require "common.pirate"

local athooks, escort, hewhew, scanHooks, squad, strafer, target, zlkPilots, zlk_list -- Non-persistent state
local rmScanHooksRaw, spawnEmpSquadron, spawnZlkSquadron -- Forward-declared functions
-- luacheck: globals backDialog convoyEnter enter escort_died escort_hailed gather hailMe killed_zlk land landBar loading rmScanHooks scanBloc spawnDrones spawnHewHew spawnStrafer straferDiscuss takeoff targetAttacked targetBoarded targetDied targetEscaped tick weNeed2land (Hook functions passed by name)
-- luacheck: globals discussHam discussNik discussStr discussThe discussTro fireSteal imperialAgent pirateDealer (NPC functions passed by name)

escort_hailed = fw.escort_hailed -- common hooks

-- TODO: add news comments about all this
-- TODO: check that no blockade has been forgotten

local hamfr_desc = _("Hamfresser and his team are together at a table. The captain drinks with his favorite pink straw while incessantly scanning the room.")
local hamfr_des2 = _("The captain sits alone at a remote table. He nervously chews his pink straw, while waiting for your signal to infiltrate the hospital.")
local nikol_desc = _("The second in command of Hamfresser's squad seems to be as laid back as a Totoran gladiator on cocaine. Clearly, open spaces like this bar with many people around are not suited to commandos, who are used to seeing strangers as a potentially hostile.")
local tronk_desc = _("The young cyborg sits to the right of his captain, and looks suspiciously at his sparkling water glass.")
local theru_desc = _("This soldier is the team's medic. As such, she seems to be slightly less combat-suited than the others, but her large cybernetically-enhanced arms still make her look like she could crush a bull.")
local straf_desc = _("The pilot is the only one in the group who looks like the other people with whom you are used to working. His presence along with the others makes the group even stranger.")

-- Mission constants
local commMass = 4
local fzlk = faction.get("Za'lek")
local hampla, hamsys = planet.getS("Vilati Vilata")
local reppla, repsys = planet.getS("Dvaer Prime")
local pripla, prisys = planet.getS("Jorla")
local zlkpla, zlksys = planet.getS("House Za'lek Central Station")
local intsys = system.get("Poltergeist")

function create()
   if planet.cur() == hampla then
      misn.finish(false)
   end

   if not misn.claim ( intsys ) then
      misn.finish(false)
   end

   misn.setNPC(_("Captain Leblanc"), fw.portrait_leblanc, _("Captain Leblanc is the top pilot of General Klank's task force. Her presence in this bar means that the High Command needs your help."))
end

function accept()
   if not tk.yesno( _("A difficult mission"), _([[As you approach, Leblanc recognizes you. "Hello, citizen. Fancy meeting you here! The Major told me I would end up finding you by browsing all the shifty places in Dvaered space. We happen to need your services once more. But this time, it will be sort of a bit... More illegal." You then wonder how something could be more illegal than helping black ops commandos assassinate a pilot, steal a corvette, and sabotage a warlord's cruiser, and you answer:]]) ) then
      tk.msg(_("Too bad"), _([["As you wish, citizen. After all, one can not obligate people to do their duty..."]]))
      misn.finish(false)
   end
   tk.msg(_("The problem to solve"), _([["Alright," Leblanc says, "Here is the situation: before starting to actually prepare our military operations, we need to protect our backs. And for that, Major Tam believes that the House Goddard is the key to ensure that the Empire will not thwart our plan. Tam would explain it much better than I, but as Goddard is right in between our space and imperial space, they really have much to lose in case of a direct conflict. What is more, as we are House Goddard's best customer, they tend to appreciate us. (For example, we recently paid 6M credits to repair all the electronics of Klank and Battleaddict's Goddards).
   However, not all members of Goddard's executive board share the same view of our Frontier invasion projects. Mr. Danftang, their Public Relations Manager, in particular, used to see it as an opportunity to sell more cruisers to the High Command and was very favourable to the invasion. This man has been arrested recently by the Za'lek police for unclear reasons and many suspect this is linked to a score-settling scheme by Goddard shareholders. As you have probably already guessed at this point, our mission is to help this man escape the Za'lek prisons."]]))
   tk.msg(_("The problem to solve"), fmt.f(_([["The target is currently imprisoned on {pripla} in {prisys}, in Za'lek's VIP carceral center on this planet. He will be transferred to {zklpla} in {zlksys} for a preliminary interview with the judge. The Za'lek don't expect anybody to try to free him by violence, so they don't take too many precautions.
   "Major Tam has prepared the operation. First, you will pick up Hamfresser and his team on {hampla} in {hamsys}. I'll be there too and then we will fly in formation to {intsys} and set up the ambush. It would be preferable if you would make sure that your ship doesn't outrun my Vendetta. There should be a few drones and a corvette. We will destroy the drones and disable the corvette, in order to let the commando unit enter the ship and recover the target. Tam has insisted that he doesn't want us to kill anybody as it could irritate the Za'lek a bit too much. After that, we will have to jump out of the system and to return to {reppla} separately.
  "A fake transponder will be implemented on both our ships. This will ensure that, provided we don't do anything stupid on our way back, we will not be recognized as hostile by the Za'lek patrols and ground control services. So we should be able to refuel without any problem on Za'lek planets."]]), {pripla=pripla, prisys=prisys, zlkpla=zlkpla, zlksys=zlksys, hampla=hampla, hamsys=hamsys, intsys=intsys, reppla=reppla}))

   misn.accept()
   misn.setDesc(_("You will help a Goddard executive to evade his Za'lek prison."))
   misn.setReward(_("Hopefully something better than Gauss Guns..."))

   mem.stage = 0
   hook.land("land")
   hook.enter("enter")
   mem.barLandHook = hook.land("landBar","bar")
   mem.loadhook    = hook.load("loading")
   misn.osdCreate( _("Dvaered Escape"), {
      fmt.f(_("Meet the rest of the team in {pnt} in {sys}"), {pnt=hampla, sys=hamsys}),
      fmt.f(_("Intercept the convoy in {sys}. Your Vendetta escort must survive"), {sys=intsys}),
      fmt.f(_("Report back on {pnt} in {sys}"), {pnt=reppla, sys=repsys}),
   } )
   mem.mark = misn.markerAdd(hamsys, "low")
end

function landBar()

   -- You land at the commando's planet
   if mem.stage == 0 and planet.cur() == hampla then
      misn.npcAdd("discussHam", _("Captain Hamfresser"), fw.portrait_hamfresser, hamfr_desc)
      misn.npcAdd("discussNik", _("Sergeant Nikolov"), fw.portrait_nikolov, nikol_desc)
      misn.npcAdd("discussTro", _("Private Tronk"), fw.portrait_tronk, tronk_desc)
      misn.npcAdd("discussThe", _("Corporal Therus"), fw.portrait_therus, theru_desc)
      misn.npcAdd("discussStr", _("Lieutenant Strafer"), fw.portrait_strafer, straf_desc)

      local c = commodity.new( N_("Commando"), N_("A commando unit.") )
      mem.commando = misn.cargoAdd( c, commMass ) -- TODO: see if it gets auto-removed at the end of mission

      tk.msg(_("Hello again"), _([[When you enter the bar, you feel an unusual atmosphere in the air. Most customers seem to be annoyed to be there, not lifting their eyes from their drinks. Even the mercenary pilots, normally easily distinguishable by their arrogant posture and their loud voices, do not manifest. Moving forward in the room, you soon discover the reason for that: Captain Hamfresser, from the space infantry commandos. And this time, he is not alone.
   The group of cyborgs sits in an empty part of the room, staring periodically at each customer and at the walls. For the first time, you think to yourself that they can probably see through most walls with their implants and try to remember if you had contraband in your ship last time they were aboard. Finally, between two cyborgs, you spot Lientenant Strafer, the pilot, apparently the only normal person who can look serene around space infantry cyborgs. Well, "normal" might be a stretch; he is a Dvaered soldier, after all.
   When you look at Hamfresser's face, you notice a large smile on it. The implants on his face do not look like they have been designed to deal with the possibility of a spacemarine trying to smile, and his skin twists horribly. You finally approach and he tells you the team is ready to leave on a moment's notice.]]) )

      mem.stage = 1
      misn.osdActive(2)
      misn.markerRm(mem.mark)
      mem.mark = misn.markerAdd(intsys, "high")

      hook.rm(mem.barLandHook)
   end
end

function land()
   mem.lastPlanet = planet.cur()

   -- You land to steal a medical machine
   if mem.stage == 3 then
      misn.npcAdd("fireSteal", _("Captain Hamfresser"), fw.portrait_hamfresser, hamfr_des2)

   -- Land at an Imperial planet and meet the agents
   elseif mem.stage == 5 and planet.cur():faction() == faction.get("Empire") then
      tk.msg(_("Other help offer"), fmt.f(_([[As you land, someone seems to be waiting for you on the spaceport. "Hello, colleague! Someone is in trouble with the authorities, out there. You seem to have had an argument with the Za'lek, and now the Imperials help them. I've seen blockades everywhere on the borders of Imperial space. Even the way to the secret jumps is impassable. It looks like the Empire wants to get you at all costs, but luckily enough, I have the solution. You probably already got a fake transponder, but they seem to have identified it, so what about receiving another one? I can sell you an authentic fake transponder, coming straight outta Skulls and Bones factory."
   This person is for sure a pirate who wants to take the opportunity to get a few credits. The idea is not bad as the imperial ships would not look for a ship with a Skulls and Bones fake transponder. So you ask him how many credits he wants. "{number}" is the answer. "That sounds a great many, doesn't it? But maybe it's a suitable amount of money for your life and the success of whatever unscrupulous mission you're trying to carry out. Of course, you may not have such an amount right here, so I'll accept if you give your word to pay me at some point. Your word and your DNA signature as well, so that I can find you if you try to trick me."
   You know that if you agree, you will have to pay whatever happens, otherwise you will be harassed by hit men until the end of your life. But actually, paying {credits} could allow you to skirt the messy and compromising deal you will otherwise have to do with the Imperial secret services. Meet the fake transponder dealer at the bar if interested.]]), {number=fmt.number(fw.pirate_price), credits=fmt.credits(fw.pirate_price)}))
      mem.pirag = misn.npcAdd("pirateDealer", _("Fake transponder dealer"), portrait.get("Pirate"), _("This shifty person is for sure one of the pirates that want to sell their fake transponder to you."))
      mem.impag = misn.npcAdd("imperialAgent", _("Feather-hat agent"), portrait.get(), _("The imperial agent looks like a nondescript trader, as there are so many in imperial space."))
      mem.stage = 6

   -- Land to end the mission
   elseif mem.stage >= 4 and planet.cur() == reppla then
      tk.msg(_("Finally back"), fmt.f(_([[Upon landing, Hamfresser, the VIP and you go to the spaceport's military office, where the Major Tam is waiting for you along with a few other soldiers. He warmly greets the executive and addresses to Hamfresser: "Do you know that you scared us, people? We learned by the diplomatic channel that you destroyed an hospital's pharmacy quasi-entirely, along with two police tanks and half a dozen battle androids on {pnt}. Apparently, you did not kill anyone at least, but the Za'lek were really upset".
   The captain explains: "Sir, we needed a machine to heal the VIP, that had been injured during the interception, but once in the hospital, we'd been apparently spotted by a traffic cop. Things then got gradually worse and we had to escape through the pharmacy's wall. I've lost a soldier in this operation." Tam answers: "Well, you will make a detailed report later. And don't worry about the soldier, I will make sure he is replaced immediately.
   "And you, {player}, anything to report?"]]), {pnt=mem.hospPlanet, player=player.name()}))
      var.push("dv_empire_deal", false)
      var.push("dv_pirate_debt", false)
      shiplog.create( "frontier_war", _("Frontier War"), _("Dvaered") )
      if mem.stage == 7 then -- Empire solution
         tk.msg(_("A problem with the Empire"), fmt.f(_([[You explain to the major what problems you encountered. You talk about the strange deal the Empire has forced you to make with them and the major's face turns red: "You did WHAT? The imperial intelligence service is the strongest in the world, they can deduce things you would not even imagine just by looking at someone, and you let them interview a black ops commando leader!"
   As you argue that you had no other choice, he seems to calm down a little bit "I will interrogate Hamfresser to see if one can understand what they were looking for. Damn! I'm afraid something awful may happen to us somehow because of that. Oh, and by the way, I made sure with the Za'lek that they don't blame you personally for what happened. They should accept you in their space now."
   The major starts to go away, but then comes back "Oh, I almost forgot to pay you. Hehe. Here are {credits}."]]), {credits=fmt.credits(fw.credits_02)}))
         var.push("dv_empire_deal", true)
         shiplog.append( "frontier_war", _("You helped the Dvaered High Command to liberate Mr. Danftang, public relations executive at Goddard, who was imprisoned by the Za'lek for obscure reasons. This executive is likely to help House Dvaered on the diplomatic point of view. Many unexpected events happened during this operation, that forced you to make a deal with the Empire secret services.") )
      elseif mem.stage == 8 then -- Pirate debt
         tk.msg(_("Everything is almost alright"), fmt.f(_([[You explain to the major what problems you encountered. You talk about the strange deal the Empire has tried to make with you. "Yes, the Imperial intelligence services are formidable. It is very hard for us to hide our intentions from them. It was right for you not to accept their offer. So you bought a pirate fake transponder, right? I hope it was not too expensive!"
  When you tell him the sum you had to promise to pay, Major Tam squeaks. "Whawhawhat? {price} for a fake transponder! This is not trade, it is theft!" "Well, technically..." You answer "those folks are pirates, so it's their job to rob people." The major calms down "Alright. I'll take care of the payment, so that they don't kill you, but you'll have to refund us, don't forget that! Oh, and by the way, I made sure with the Za'lek that they don't blame you personally for what happened. They should accept you in their space now."
   The major starts to go away, but then comes back "Oh, I almost forgot to pay you. Hehe. Here are {credits}."]]), {price=fmt.credits(fw.pirate_price), credits=fmt.credits(fw.credits_02)}))
         var.push("dv_pirate_debt", true)
         shiplog.append( "frontier_war", _("You helped the Dvaered High Command to liberate Mr. Danftang, public relations executive at Goddard, who was imprisoned by the Za'lek for obscure reasons. This executive is likely to help House Dvaered on the diplomatic point of view. Many unexpected events happened during this operation, that forced you to get into debt with House Dvaered. It is very likely they won't entrust you with important missions until you repay them.") )
      elseif mem.stage == 9 then -- Pirate cash
         tk.msg(_("No major problem to report"), fmt.f(_([[You explain to the major what problems you encountered. You talk about the strange deal the Empire has tried to make with you. "Yes, the Imperial intelligence services are formidable. It is very hard for us to hide our intentions from them. It was right for you not to accept their offer. So you bought a pirate fake transponder, right? I hope it was not too expensive!"
   You consider requesting to be refunded for your mission expenses, but then you remember that the Dvaered are tightfisted and violent, so you give up and simply answer: "Oh, no... not... really."
   Tam looks satisfied, and answers: "By the way, I made sure with the Za'lek that they don't blame you personally for what happened. They should accept you in their space now."
   The major starts to go away, but then comes back "Oh, I almost forgot to pay you. Hehe. Here are {credits}."]]), {credits=fmt.credits(fw.credits_02)}))
         shiplog.append( "frontier_war", _("You helped the Dvaered High Command to liberate Mr. Danftang, public relations executive at Goddard, who was imprisoned by the Za'lek for obscure reasons. This executive is likely to help House Dvaered on the diplomatic point of view. Many unexpected events happened during this operation, that forced you to buy a fake transponder at an outrageous price.") )
      else -- Normally, the player should not achieve that (maybe with a trick I did not foresee, but it should be Xtremely hard)
         tk.msg(_("No major problem to report"), fmt.f(_([[You explain to the major what problems you encountered. You talk about the strange deal the Empire has tried to make with you. "Yes, the Imperial intelligence services are formidable. It is very hard for us to hide our intentions from them. It was right for you not to accept their offer. I guess it should have been very hard and risky to skirt the imperial blocus, congratulations! Oh, and by the way, I made sure with the Za'lek that they don't blame you personally for what happened. They should accept you in their space now."
  The major starts to go away, but then comes back "Oh, I almost forgot to pay you. Hehe. Here are {credits}."]]), {credits=fmt.credits(fw.credits_02)}))
         shiplog.append( "frontier_war", _("You helped the Dvaered High Command to liberate Mr. Danftang, public relations executive at Goddard, who was imprisoned by the Za'lek for obscure reasons. This executive is likely to help House Dvaered on the diplomatic point of view. Many unexpected events happened during this operation, but you managed to survive somehow.") )
      end
      player.pay(fw.credits_02)

      -- Reset the zlk standing.
      local stand1 = fzlk:playerStanding()
      fzlk:modPlayerRaw( mem.stand0-stand1 )
      var.pop("loyal2klank") -- We don't need this one anymore
      misn.finish(true)
   end

   mem.lastPla = planet.cur()
end

-- Put the npcs back at loading
function loading()
   if mem.stage == 1 and planet.cur() == hampla then
      misn.npcAdd("discussHam", _("Captain Hamfresser"), fw.portrait_hamfresser, hamfr_desc)
      misn.npcAdd("discussNik", _("Sergeant Nikolov"), fw.portrait_nikolov, nikol_desc)
      misn.npcAdd("discussTro", _("Private Tronk"), fw.portrait_tronk, tronk_desc)
      misn.npcAdd("discussThe", _("Corporal Therus"), fw.portrait_therus, theru_desc)
      misn.npcAdd("discussStr", _("Lieutenant Strafer"), fw.portrait_strafer, straf_desc)
   elseif mem.stage == 3 then
      misn.npcAdd("fireSteal", _("Captain Hamfresser"), fw.portrait_hamfresser, hamfr_des2)
   --elseif mem.stage == 4 then -- TODO: decide if we do that
      --player.takeoff()
   end
end

-- Optional discussions with the team
function discussHam()
   tk.msg(_("Captain Hamfresser"), fmt.f(_([["Hello, {player}! You remember us?" Asks the captain, apparently unaware of the fact that his appearance is hard to forget. "We are ready to embark whenever you want, pilot! You'll just have to make space for {tonnes} of cargo (we have some equipment). Oh yes, and there is apparently a small change in the plan regarding the Captain Leblanc. She won't be able to join us. Talk to the Lieutenant, he will explain it better."]]), {player=player.name(), tonnes=fmt.tonnes(commMass)}))
end
function discussNik()
   tk.msg(_("Sergeant Nikolov"), _([["Hello, citizen. I guess you would want to speak with the officers to have details about the plan. But tell me while you are here: there are many people in this room, but none of them is sitting at the tables next to ours. Do you know what is wrong with this part of the room?" You answer that the people probably feel unsafe sitting next to a group of dangerous-looking cyborgs like them, and she answers: "Meh, I don't think you're right. When I am in the Space Infantry refectory, there are dangerous-looking cyborgs all around and nobody feels unsafe. There should be something else..."]]))
end
function discussTro()
   tk.msg(_("Private Tronk"), _([["I have ordered water and the waiter gave me that glass, with lots of bubbles. It does not look safe. Do you know what it is? I hope it's not alcohol..." As you tell him that it is simply sparkling water, and that it doesn't contain alcohol nor anything toxic, he gratefully answers: "Whoa, you really look like an expert in drinks! You know, I was asking because we cyborgs of class gamma can't drink alcohol. Each morning we have to take a special medication, the Spacemarine's Cocktail, to ensure that our organism supports our biological and cybernetic implants, and this cocktail is incompatible with any alcohol.
   "My brother drank a beer once by mistake, and he had to spend two months at hospital. But he is going better now, and he is back in his unit." You ask him if everyone in his family is as strong as he is and he answers: "Oh no, by little sister is much stronger. She fights on Totoran in the 1v1 bare hand championship, and she won 6 matches in a row, last season. But I am afraid she won't be able to take part to this cycle's championship as she did not fully recover from her decapitation during her last fight."]]))
end
function discussThe()
   tk.msg(_("Corporal Therus"), fmt.f(_([["Hi, citizen. Are you ready to transport us once more? Have you spoken to the Captain? And to the pilot? I don't really know the details of the operation, so you'll have to ask them."
   The corporal seems to hesitate, and then continues: "Today, the Lieutenant asked me a riddle: let's say Major Tam is running after a turtle. When Major Tam arrives at the point where the turtle was when he started to run, the turtle has moved forward a bit in the same time, right? Then, he arrives at the point where the turtle was when he reached the previous point, but the turtle has again moved forward. And so on. Conclusion: Major Tam is quicker than the turtle, but he never catches up. How is that possible?"
   Strafer then arrives: "Yep, I've been to the museum of Theras one day, and this riddle was written on a book from before the space age. The name of the author was: 'Senior High School Philosophy Class' that's a strange name actually. I remembered that riddle while we were hiking on {pnt} not so long ago, and we saw a turtle."]]), {pnt=_(fw.wlrd_planet)}))
end
function discussStr()
   tk.msg(_("Lieutenant Strafer"), _([[You look at the lieutenant, surprised not to see the captain Leblanc, as expected. "Unplanned things have happened. The general has been attacked in Doranthex by mercenary pilots and our squadron had to rescue him. The second in command got killed, so Leblanc can not delegate her command anymore. We need her to lead the squadron, and she sent me instead. Do not worry, I might be slightly less gifted than her, but I am still a dogfight ace. I have got 15 attested dogfight victories so far, you know, and that does not take into account the secret operations I have taken part in.
   "So on the way in, I will follow you with my civilian Vendetta, and you will just have to hail me if you want me to do anything special. During the interception, I'll focus on the drones so that you can take on the main ship. For the way back, as planned, we will take separate ways. We take off when you decide."]]))
end

function fireSteal()
   if tk.yesno(_("Ready for action?"), _([[Are you ready to start "Operation Drugstore Thunder"? (Hamfresser named it.)]])) then
      tk.msg(_("At the hospital"), _([[After giving the signal to Hamfresser, you join the cockpit of your ship and start the motors in anticipation of an escape. A heavy explosion coming from the distance shakes your ship, followed by detonations that seem to approach. After a while, you see the commandos running in your direction, pursued by Za'lek police androids. When the last member of the team enters the ship, you take off in a hurry, closely followed by a few drones. "We made a mess, out there!" Says Hamfresser "But at least we've got the machine!"]]))
      mem.stage = 4
      misn.osdDestroy()
      misn.osdCreate( _("Dvaered Escape"), {
         fmt.f(_("Escape to {pnt} in {sys}. Do NOT destroy any Za'lek inhabited ship (only drones are allowed)"), {pnt=reppla, sys=repsys}),
      } )
      hook.pilot(nil, "death", "killed_zlk")

      mem.hospPlanet = planet.cur()
      hook.takeoff("takeoff")
      player.takeoff()
      mem.firstBloc = true
      hook.rm(mem.datehook)
   end
end

-- Test to see if the player killed a zlk inhabited ship
function killed_zlk(pilot,killer)
   if pilot:faction() == fzlk
         and (killer == player.pilot()
            or killer:leader() == player.pilot()) then
      mem.killed_ship = pilot:ship():nameRaw()
      if (fw.elt_inlist( mem.killed_ship, {"Za'lek Scout Drone", "Za'lek Light Drone", "Za'lek Heavy Drone", "Za'lek Bomber Drone"} ) == 0) then
         tk.msg(_("The mission failed"), _([[The rule was not to kill anybody, did you remember?]]))
         misn.finish(false)
      end
   end
end

function enter()
   -- Intercept the ship
   if mem.stage == 1 and system.cur() == intsys then
      mem.stand0 = fzlk:playerStanding() -- To reset it after the fight

      pilot.toggleSpawn(false)
      pilot.clear()
      mem.prevsys = lmisn.getNextSystem(system.cur(), prisys)
      mem.nextsys = lmisn.getNextSystem(system.cur(), zlksys)

      hook.timer(5.0, "convoyEnter")

   -- At first jump, it gets announced that you've got to land
   elseif mem.stage == 2 then
      hook.timer( 7.0, "weNeed2land" )

   elseif mem.stage == 4 and mem.tronkDeath then
      mem.tronkDeath = false
      tk.msg(_("Journey to the other side"), _([[After having outrun your enemies, you start inquiring about how the operation went at the hospital. A quick look at your living quarters gives you an answer. You see the VIP, still unconscious, but not blue anymore, his body covered by electrodes connected to the machine in question. Next to him, the commandos look like they had better days. Hamfresser, his face as pale as death, sits on the ground, leaning on a pillar, busy changing a long and blood-dripping bandage on his left arm. The sergeant Nikolov looks at a huge hole in her foot with an empty eye and the medic Therus limps from the one to the other, spreading blood marks on the walls.
   Lying in the center of the room, covered with bandages, is private Tronk. His battle armor, pierced with multiple holes, has been thrown a few meters away in a blood puddle. The soldier looks at the two remaining fingers of his less damaged arm that are slowly walking on the ground, in a sad smile. "Leopold, you remember when you were a kid? Did you play with your fingers like that?" Hamfresser answers: "Tronky-boy, don't use my first name, only dying people have used my first name before..." "Don't be afraid, this won't change, Leopold."
   Suddenly, the soldier opens his eyes wide and calls the medic: "Therus! I know why Major Tam can catch the turtle! Each time, when he reaches the point where the turtle previously was, the time he needs for that is smaller. And at some point, it becomes so infinitely small that even if you have an infinity of steps to go, the total time is finite." The medic looks at the dying man: "Tronky, how did you? Tronky?" She then stops and takes the pulse at Tronk's neck "It's over, captain." Hamfresser answers: "Damn! It's the fifth kid to die under my command and it still hurts as much. I just can't get used to that."]])) -- The death of Tronk

   -- When entering Empire Space, contact with Captain HewHew
   elseif mem.stage == 4 and system.cur():presences()["Empire"] and (not system.cur():presences()["Za'lek"]) then
      hook.timer(2.0, "spawnHewHew", mem.lastSys)
      hook.timer(10.0, "backDialog")  -- And some dialog with the VIP
   end

   -- Spawn Strafer
   if mem.stage == 1 then
      local origin
      if mem.lastSys == system.cur() then -- We're taking off
         origin = mem.lastPla
      else
         origin = mem.lastSys
      end

      strafer = pilot.add("Vendetta", "DHC", origin, _("Lieutenant Strafer"), {ai="baddie_norun"})
      strafer:setHilight()
      strafer:setVisplayer()

      -- give him top equipment
      strafer:outfitRm("all")
      strafer:outfitRm("cores")
      strafer:outfitAdd("S&K Light Combat Plating")
      strafer:outfitAdd("Tricon Zephyr II Engine")
      --strafer:outfitAdd("Solar Panel")
      strafer:outfitAdd("Milspec Orion 3701 Core System")
      strafer:outfitAdd("Gauss Gun", 3)
      strafer:outfitAdd("Vulcan Gun", 3)

      strafer:setHealth(100,100)
      strafer:setEnergy(100)
      strafer:setFuel(true)

      -- Behaviour
      strafer:control(true)
      strafer:follow( player.pilot(), true )
      hook.pilot(strafer, "death", "escort_died")
      hook.pilot(strafer, "hail", "escort_hailed")
   end

   if mem.stage >= 4 then
      -- Zlk Blocus:
      -- Pultatis -> Provectus Nova
      --          -> Limbo
      -- Stone Table -> Sollav
      -- Xavier -> Sheffield
      -- Straight Row -> Nunavut
      zlk_list = { system.get("Pultatis"), system.get("Stone Table"), system.get("Xavier"), system.get("Straight Row") }
      local zlk_lisj = { {"Provectus Nova", "Limbo"}, {"Sollav"}, {"Sheffield"}, {"Nunavut"} }

      mem.index = fw.elt_inlist( system.cur(), zlk_list )
      if mem.index > 0 then -- /!\ We did not claim this system /!\
         pilot.toggleSpawn("Za'lek")
         pilot.clearSelect("Za'lek")
         for k,f in ipairs(pir.factions) do
            pilot.toggleSpawn(f)
            pilot.clearSelect(f)
         end

         if mem.firstBloc then
            scanHooks = {}
            mem.jpoutHook = hook.jumpout("rmScanHooks")
         end
         for i, j in ipairs(zlk_lisj[mem.index]) do
            local jp = jump.get( system.cur(), j )
            local pos = jp:pos()
            spawnZlkSquadron( pos, (mem.stage < 8) )
         end
      end

   -- Empire Blocus:
   -- Overture -> Pas
   --          -> Waterhole
   -- Eneguoz  -> Hakoi
   -- Mural -> Salvador
   -- Arcturus -> Goddard /!\ This one is passable if deal with the empire /!\
   -- (Delta Pavonis -> Goddard) ? TODO: this one is not necessary
   -- Fortitude -> Pontus
   --           -> Acheron
   -- Merisi -> Acheron
      local emp_list = { system.get("Overture"), system.get("Eneguoz"), system.get("Mural"), system.get("Arcturus"),
                         system.get("Delta Pavonis"), system.get("Fortitude"), system.get("Merisi") }
      local emp_lisj = { {"Pas", "Waterhole"}, {"Hakoi"}, {"Salvador"}, {"Goddard"}, {"Goddard"}, {"Pontus", "Acheron"}, {"Acheron"} }

      mem.index = fw.elt_inlist( system.cur(), emp_list )
      if mem.index > 0 then -- /!\ We did not claim this system /!\
         pilot.toggleSpawn("Za'lek")
         pilot.clearSelect("Za'lek")
         pilot.toggleSpawn("Pirate")
         pilot.clearSelect("Pirate")

         for i, j in ipairs(emp_lisj[mem.index]) do
            local jp = jump.get( system.cur(), j )
            local pos = jp:pos()
            if system.cur() == system.get("Arcturus") and j == "Goddard" and mem.stage == 7 then -- Special case: JP from Arcturus to Goddard
               spawnEmpSquadron( pos, false )
            else
               spawnEmpSquadron( pos, (mem.stage < 8) )
            end
         end
      end

   end

   mem.lastSys = system.cur()
end

-- Functions for the escort
function escort_died()
   tk.msg(_("Mission Failed: escort destroyed"), _("Your escort died. You have to abort the mission"))
   misn.finish(false)
end

-- Makes the carceral convoy enter the system
function convoyEnter()
   target = pilot.add( "Za'lek Sting", "Za'lek", mem.prevsys )
   target:memory().formation = "wedge"
   target:setHilight()
   target:setVisible()
   target:control(true)
   target:hyperspace(mem.nextsys)

   escort = {}
   escort[1] = pilot.add( "Za'lek Light Drone", "Za'lek", mem.prevsys, nil, {ai="collective"} )
   escort[2] = pilot.add( "Za'lek Light Drone", "Za'lek", mem.prevsys, nil, {ai="collective"} )
   escort[3] = pilot.add( "Za'lek Heavy Drone", "Za'lek", mem.prevsys, nil, {ai="collective"} )
   --escort[4] = pilot.add( "Za'lek Heavy Drone", "Za'lek", mem.prevsys, nil, {ai="collective"} )

   athooks = {}
   for i, p in ipairs(escort) do
      p:setLeader(target)
      athooks[i] = hook.pilot(p, "attacked", "targetAttacked")
   end

   mem.attackhook = hook.pilot(target, "attacked", "targetAttacked")
   mem.boardhook  = hook.pilot(target, "board", "targetBoarded")
   hook.pilot( target, "death", "targetDied" )
   hook.pilot( target, "jump", "targetEscaped" )
   hook.pilot( target, "land", "targetEscaped" )
   -- TODO: not possible to jump nor to land
end

-- Hooks for the interception target
function targetAttacked()
   strafer:control(false)
   hook.rm(mem.attackhook)
   for i, j in ipairs(athooks) do
      hook.rm(j)
      escort[i]:setFaction("Warlords") -- Hack so that Strafer attacks them and not the Sting
   end
   target:setHostile(true)

   -- Decide between fight or runaway
   if player.pilot():ship():size() > 3 then
      target:taskClear()
      target:comm( _("Just try to catch me, you pirate!") )
      target:runaway(player.pilot())
   else
      target:control(false)
      target:comm( _("You made a very big mistake!") )
   end
end
function targetBoarded()
   tk.msg(_("A new passenger"), _([[The commandos gather near the airlock. This time, four combat androids are in the front. Hamfresser gives his orders and the first android smashes the enemy ship's airlock with its fist. After that, the team rushes into the ship and the explosions start to thunder. Before long, the team comes back. Nikolov enters first, carrying an immobile and blue man in a prisoner suit, then Hamfresser, followed by the medic Therus, busily applying compresses on a large bloody wound on the captain's side, and by Tronk, who seems to be trying to explain himself. After that come the androids, that seem to have received heavy damage. You jump at the cockpit and start the engines.]]))
   player.unboard()
   hook.rm(mem.boardhook)

   mem.stage = 2
   misn.osdActive(3)
   misn.markerRm(mem.mark)
   mem.mark = misn.markerAdd(repsys, "low")

   -- Reset the zlk standing
   local stand1 = fzlk:playerStanding()
   fzlk:modPlayerRaw( mem.stand0-stand1 )
end
function targetDied()
   tk.msg(_("Mission Failed: target destroyed"), _("You were supposed to disable that ship, not destroy it. How are you supposed to free anyone now?"))
   misn.finish(false)
end
function targetEscaped()
   tk.msg(_("Mission Failed: target escaped"), _("You were supposed to disable that ship, not let it escape. How are you supposed to free anyone now?"))
   misn.finish(false)
end

-- Hamfresser explains that we need to land at an hospital
function weNeed2land()
   mem.stage = 3
   tk.msg(_("We are in trouble"), _([[While you finally jump out, Hamfresser reports: "We've got an unexpected situation in there. After we destroyed the androids, and got to the imprisonment room, we saw that there were three other prisoners along with the target, and much more human guards than expected. They exploded our first assault bot, and we had to take them down with the paralyzers, but one of the prisoners took a weapon for some reason and started to fire on us. Fortunately for me, he just breached my lung. That is a replaceable part.
   "Then, Tronk paralyzed all the prisoners and we identified and recovered the target. That's why the guy is blue actually. But in his hurry, Tronk used the armor-piercing dose. According to the medic, it is worse that we first thought. Apparently, she can keep the guy alive for a few periods, but she needs a machine that is not on board to save him. So at next stop, I'm afraid we will have to steal the machine at the spaceport's hospital. It really annoys me as it's the kind of operation that can get ugly very quickly, especially since the killing interdiction still runs, but we have no choice. I'll just be waiting for your signal at the bar next time we land.
   "If I may, I'd advise you to land somewhere within 3 periods, otherwise the VIP is likely to die, and to choose a place with a shipyard and an outfitter so that you'll be able to prepare your ship at best in case we need to escape quickly."]]))
   mem.timelimit = time.get() + time.create(0,3,0)
   misn.osdCreate(_("Dvaered Escape"), {
      fmt.f(_("Land anywhere to let Hamfresser steal a machine. Time left: {time}"), {time=(mem.timelimit - time.get())}),
   })
   mem.datehook = hook.date(time.create(0, 0, 100), "tick")
end

function tick()
   if mem.timelimit >= time.get() then
      misn.osdCreate(_("Dvaered Escape"), {
         fmt.f(_("Land anywhere to let Hamfresser steal a machine. Time left: {time}"), {time=(mem.timelimit - time.get())}),
      })
   else
      tk.msg(_("The mission failed"), fmt.f(_([[Hamfresser rushes to the bridge. "All is lost, {player}! The guy died. Our mission failed!"]]), {player=player.name()}))
      misn.finish(false)
   end
end

function takeoff( )
   -- Player takes off from planet after attacking the hospital
   if mem.stage == 4 and mem.lastPlanet:faction() == fzlk then
      fzlk:modPlayerRaw( -100 )
      hook.timer(1.0, "spawnDrones")

      -- Clear all Zlk pilots in a given radius of the player to avoid being insta-killed at takeoff
      local dmin2 = 500^2
      zlkPilots = pilot.get( { fzlk } )
      for i, p in ipairs(zlkPilots) do
         if vec2.dist2(player.pos()-p:pos()) < dmin2 then
            p:rm()
         end
      end
   end
end

-- Drones are after the player after the hospital attack
function spawnDrones()
   pilot.add( "Za'lek Light Drone", "Za'lek", mem.lastPlanet, nil, {ai="collective"} )
   pilot.add( "Za'lek Light Drone", "Za'lek", mem.lastPlanet, nil, {ai="collective"} )
   pilot.add( "Za'lek Heavy Drone", "Za'lek", mem.lastPlanet, nil, {ai="collective"} )
   mem.tronkDeath = true -- This says that at next jump, Tronk will die
end

-- Spawn blockade ships
function spawnZlkSquadron( pos, bloc )
   squad = {}
   squad[1]  = pilot.add( "Za'lek Mephisto", "Za'lek", pos )
   squad[2]  = pilot.add( "Za'lek Demon", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[3]  = pilot.add( "Za'lek Demon", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[4]  = pilot.add( "Za'lek Sting", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[5]  = pilot.add( "Za'lek Sting", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )

   squad[6]  = pilot.add( "Za'lek Light Drone", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300), nil, {ai="collective"} )
   squad[7]  = pilot.add( "Za'lek Light Drone", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300), nil, {ai="collective"} )
   squad[8]  = pilot.add( "Za'lek Heavy Drone", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300), nil, {ai="collective"} )
   squad[9]  = pilot.add( "Za'lek Heavy Drone", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300), nil, {ai="collective"} )

   squad[10] = pilot.add( "Za'lek Bomber Drone", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300), nil, {ai="collective"} )
   squad[11] = pilot.add( "Za'lek Bomber Drone", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300), nil, {ai="collective"} )
   squad[12] = pilot.add( "Za'lek Bomber Drone", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300), nil, {ai="collective"} )
   squad[13] = pilot.add( "Za'lek Bomber Drone", "Za'lek", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300), nil, {ai="collective"} )

   for i, j in ipairs(squad) do
      j:setSpeedLimit( .0001 ) -- 0 disables the stuff so it's unusable
      j:setHostile(bloc)
   end

   if mem.firstBloc then
      scanHooks[#scanHooks+1] = hook.timer(0.5, "proximityScan", {focus = squad[2], funcname = "scanBloc"})
   end
end
function spawnEmpSquadron( pos, bloc )
   squad = {}
   squad[1]  = pilot.add( "Empire Hawking", "Empire", pos )
   squad[2]  = pilot.add( "Empire Pacifier", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[3]  = pilot.add( "Empire Pacifier", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[4]  = pilot.add( "Empire Admonisher", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[5]  = pilot.add( "Empire Admonisher", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )

   squad[6]  = pilot.add( "Empire Shark", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[7]  = pilot.add( "Empire Shark", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[8]  = pilot.add( "Empire Lancelot", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[9]  = pilot.add( "Empire Lancelot", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )

   squad[10] = pilot.add( "Empire Lancelot", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[11] = pilot.add( "Empire Lancelot", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[12] = pilot.add( "Empire Lancelot", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )
   squad[13] = pilot.add( "Empire Lancelot", "Empire", pos + vec2.new(rnd.sigma()*300, rnd.sigma()*300) )

   for i, j in ipairs(squad) do
      j:setSpeedLimit( .0001 ) -- 0 disables the stuff so it's unusable
      j:setHostile(bloc)
   end
end

-- The player sees the blocus fleet
function scanBloc()
   if mem.firstBloc then -- avoid having that happening twice in systems where there are 2 blocus
      tk.msg(_("Troubles straight ahead!"), _([[When approaching the jump point, your sensors pick up a squadron of military ships, that stationnate close to the jump point in a tight formation. No doubt those ships are here for you, and it looks more than chancy to try to force the blockade.]]))

      player.pilot():control()
      player.pilot():brake() -- Normally, nobody should want to kill the player
      player.cinematics( true )
      camera.set( squad[1]:pos() ) -- TODO if possible: choose the right squad

      rmScanHooksRaw()
      mem.firstBloc = false
      hook.timer(4.0, "spawnStrafer")
   end
end

-- Strafer enters the system
function spawnStrafer()
   strafer = pilot.add( "Gawain", "Trader", _("Trader Gawain") )
   strafer:setHilight(true)
   strafer:setVisible(true)
   strafer:control(true)
   strafer:follow( player.pilot() )
   camera.set( strafer )
   mem.prox = hook.timer(0.5, "proximity", {anchor = strafer, radius = 2000, funcname = "straferDiscuss", focus = player.pilot()})
end

-- The player discuss with Strafer
function straferDiscuss()
   hook.rm(mem.prox)
   camera.set()
   player.cinematics(false)
   player.pilot():control(false)

   tk.msg(_("A friend in the dark"), fmt.f(_([[The Gawain hails you. When you respond, you hear a familiar voice. "Strafer here. I was wondering why you were so long. It looks like you had troubles with the Za'lek after all. There are blockades in {1}, {2}, {3} and {4}. They scan all ships, you have no chance to cross these systems alive. What have you done to them to upset them like that? Anyway, I did not come empty-handed. I've got as much fuel as you want. Unfortunately, I can't board you as they would chase me as well, so I have jettison a few tanks at coordinates I will give to you. Just go there and scoop them. Good luck!"]]), zlk_list ) )
   strafer:control(false)  -- Strafer stops following the player

   -- Add some fuel, far away so that no npc gathers it
   local cfuel = commodity.new( N_("Fuel"), N_("Tanks of usable fuel."), {gfx_space="fuel.webp"})
   local pos = vec2.new( -1.2*system.cur():radius(), 0 )
   system.addGatherable( cfuel, 1, pos, vec2.new(0,0), 3600 ) -- Lasts for an houer
   mem.Imark = system.mrkAdd( pos, _("FUEL") )
   mem.gathHook = hook.gather("gather")
end

-- Player gathers fuel
function gather( comm, qtt )
   -- Only care about fuel
   if comm~="Fuel" then
      return
   end
   hook.rm(mem.gathHook)
   pilot.cargoRm( player.pilot(), comm, qtt )
   player.pilot():setFuel(true)
   player.msg( _("You filled your fuel tanks.") )
   system.mrkRm(mem.Imark)
end

-- Remove scan hooks
function rmScanHooks()
   rmScanHooksRaw()
   hook.rm(mem.jpoutHook)
end
function rmScanHooksRaw()
   if scanHooks ~= nil then
      for i, j in ipairs(scanHooks) do
         hook.rm(j)
      end
      scanHooks = nil
   end
end

-- Spawns the odd imperial pilot
function spawnHewHew( origin )
   hewhew = pilot.add("Hyena", "Independent", origin, _("Strange Pilot"))
   hewhew:setInvincible()  -- Don't wreck my Captain HewHew
   hewhew:hailPlayer()
   mem.hailie = hook.pilot(hewhew, "hail", "hailMe")
end
function hailMe()
   hook.rm(mem.hailie)
   player.commClose()
   tk.msg( _("Help offer"), fmt.f(_([[The pilot of the ship starts to talk with a strange and disturbing familiarity: "Doing good, folks? Ya just walked into those Za'lek's freaks' space, wrecked a squadron, helped a prisoner escape and desolated an hospital. You're worse than the Incident, mates!" You wonder how this pilot could know so much about your operation, but the spiel continues: "Hewhewhew! People usually think I'm some useless pirates scum. I know you thought that! Neh, don't lie to me!"
   The pilot's voice suddenly becomes harsh: "In reality, I am a faithful subject of his Imperial Majesty, as you should be yourself, {player} from Hakoi! But you denied your own nation, and for that you should be severely punished. Don't forget, {player}: The Empire is watching you. Anywhere. Anytime. Anyhow.
   "Hewhewhew! And what was the other one already? Oh yeah: The Emperor sees all! So old-fashioned! Hey! But ya're all lucky, 'cause the Empire feels in a merciful mood today. So at your next stop, you will kindly go and talk to the agent with a feather hat, and both of you will agree on a way for us not to kill you!"]]), {player=player.name()}) )
   mem.stage = 5
end

-- Discuss with the Pirate or Imperial agent
function pirateDealer()
   local c = tk.choice(_("Other help offer"),
      fmt.f(_("Do you accept the deal with the pirates? It costs {price}, and you'll be able to skirt any imperial blocus."), {price=fmt.credits(fw.pirate_price)}),
   _("Accept, immediate payment"), _("Accept, deferred payment"), _("Refuse"))
   if c == 1 then
      if player.credits() >= fw.pirate_price then
         player.pay(-fw.pirate_price)
         tk.msg(_("Immediate payment"),_([[When you give the credit chip, the pirate looks surprised: "Whow, mate, I didn't know I was talking to a millionaire. Well then thanks, here is your transponder."]]))
         misn.osdDestroy()
         misn.osdCreate( _("Dvaered Escape"), {
            fmt.f(_("Escape to {pnt} in {sys}. Thanks to your new fake transponder, the squadrons should not stop you anymore"), {pnt=reppla, sys=repsys}),
         } )
         misn.npcRm(mem.pirag)
         mem.stage = 9
      else
         tk.msg(_("Not enough money"), _([["Don't try to trick me, crook! I can see from here that you don't have enough money!"]]))
      end
   elseif c == 2 then
      tk.msg(_("Pirate debt"),_([["Here is your transponder," the pirate says. "Don't forget to pay once you can, otherwise..."]]))
      misn.osdDestroy()
      misn.osdCreate( _("Dvaered Escape"), {
         fmt.f(_("Escape to {pnt} in {sys}. Thanks to your new fake transponder, the squadrons should not stop you anymore"), {pnt=reppla, sys=repsys}),
      } )
      misn.npcRm(mem.pirag)
      mem.stage = 8
   else
      tk.msg(_("You're way too expensive"),_([["As you wish," says the pirate. "Just come back when you've understood that I'm your only chance!"]]))
   end
end
function imperialAgent()
   if tk.yesno(_("Deal with the Empire"), fmt.f(_([[As you approach, the agent seems to recognize you at first sight. "Hello, {player}. I guess they told you that I may have the solution to your little... problem." You look suspiciously at the agent and ask: "What do you want in exchange?" The other one smiles: "Simple. I want to speak with the Dvaered captain. Give me 10 hecotseconds on the spacedock alone with him, not more, and the commander of the fleet in Alteris will forget to scan your ship when you'll jump to Goddard."
   That is for sure an uncommon request. You think at all the state secrets a wounded Hamfresser is able to give to the Empire in 10 hectoseconds. You then remember that, after all, Hamfresser is a professional, trained not to reveal any valuable information. But probably the imperial agent is a professional as well, trained to recover valuable information, and on the other hand, the pirate proposition still holds. So you answer:]]), {player=player.name()})) then
      tk.msg(_("You made the only good choice"),_([[After accepting, you invite the agent to follow you to the dock. You then enter your ship, where the commandos are waiting for you and inform Hamfresser on the situation. He anxiously looks at the two other remaining members of his team. Nikolov grimaces and Therus nervously hits the wall. "If you think we have no other choice..." Says the captain. After removing his uniform jacket (where his name and rank are written), Hamfresser takes a deep breath and joins the imperial agent outside, in front of the ship. From a window, you see them having what looks like a peaceful conversation.
   After a while, Hamfresser returns in the ship and the agent waves to indicate that you're allowed to take off. Nikolov ask her captain: "And?" "Who knows what these imperial weirdos wanted to know? I tried to dodge all the questions, but well. You never know."]]))
      misn.osdDestroy()
      misn.osdCreate( _("Dvaered Escape"), {
         fmt.f(_("Escape to {pnt} in {sys}. Thanks to your deal with the Empire, the squadron in Alteris won't prevent you from jumping to Goddard"), {pnt=reppla, sys=repsys}),
      } )
      misn.markerAdd( system.get("Alteris"), "plot" )
      misn.npcRm(mem.impag)
      mem.stage = 7
   else
      tk.msg(_("That was the wrong answer"),_([["Mwell." Says the agent. "I guess you want to see for yourself that this is the only solution. If you're still alive when you're done, come back, we will be waiting for you."]]))
   end
end

function backDialog()
   tk.msg(_("Shock of two worlds"), _([[You hear an unusual and edgy voice coming from the living quarters. When you go there, you see that the VIP is back on his feet. "To sum up, a Dvaered general, whose name you don't want to tell, sent you to free me from the Za'lek, for a reason you don't want to tell, right?" Hamfresser answers: "Totally correct, sir."
   The executive moans and shakes his head "You Dvaered are silly! Do you think that violence is the solution to any problem?" Hamfresser seems surprised "Is there any other way to solve a problem?" The VIP then looks at you: "Hey, you seem a bit less fussy than the others... You're not a Dvaered, right? You know what? My grandma was always saying that the worst in the universe were the Dvaered and the Za'lek. And she was right. First the Za'lek imprisoned me under charge of 'scientific embezzlement' for alien motives, and now, you Dvaered shred your way to my cell and kidnap me."
   Hamfresser defends himself: "But sir, if the operation succeeds, you'll be back to business really soon. Isn't that wonderful?" "... and if the operation fails, we all die! No, strong-arm, learn that patience, negotiation, bribing and craftiness can achieve much more than violence and destruction. I have paid the best lawyers in Za'lek space and my assistants negotiate with the authorities, I was sure to get out in about half a cycle." Hamfresser simply raises his shoulders: "Dvaered warriors don't use deception, not patience, nor craftiness. Dvaered warriors use respectable methods instead, like violence and destruction."]]))
end

-- Aborting if mem.stage >= 4: reset zlk reputation
function abort()
   if mem.stage >= 4 then
      local stand1 = fzlk:playerStanding()
      fzlk:modPlayerRaw( mem.stand0-stand1 )
   end
end
