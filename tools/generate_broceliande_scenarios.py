#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_broceliande_scenarios.py — v7.7.22 (2026-05-17)

Generate 100 LLM-reference scenarios for the Brocéliande biome with hand-crafted
druidic prose templates + procedural variant assembly + HTML output.

User mandate : « 100+ scénarios pour broceliande en exemple qui servirons pour
le LLM en guise de gage de qualité rédactionnelle ... rédaction de haute volée,
rebondissements, scénarios calmes ... 25 cartes / 11 cartes ... doc HTML ».

Output : ~/Downloads/broceliande_scenarios_v7.7.22.html + .json
"""

from __future__ import annotations
import json
import random
import sys
from pathlib import Path
from datetime import datetime

# ═══════════════════════════════════════════════════════════════════════════════
# 1. ARCHETYPES — 10 narrative patterns canonical to Brocéliande
#    (bible §7.1 = Liminal-dominant ; distribution 4 Liminal / 3 Ordre / 3 Chaos)
# ═══════════════════════════════════════════════════════════════════════════════

ARCHETYPES = [
    {"id": "druidic_awakening", "name": "L'Éveil Druidique", "pole": "Liminal",
     "emotion_arc": ["curiosite", "emerveillement", "fascination", "sagesse"],
     "essence": "Le druide novice découvre une présence ancienne dans la forêt.",
     "hook": "La mousse sous tes pieds frémit comme une langue qui se souvient de ton nom.",
     "length_pref": [11, 15, 17], "twist_pattern": "calm_revelation"},
    {"id": "korrigan_trickery", "name": "La Ruse des Korrigans", "pole": "Chaos",
     "emotion_arc": ["curiosite", "fascination", "peur", "colere", "sagesse"],
     "essence": "De petits esprits malicieux te détournent du chemin, mais leurs farces cachent un message.",
     "hook": "Un rire d'enfant éclate sous un champignon. Le champignon n'est pas là un instant plus tôt.",
     "length_pref": [11, 15, 17, 21], "twist_pattern": "deception_unveiled"},
    {"id": "ancient_oak_counsel", "name": "Le Conseil du Chêne Ancien", "pole": "Ordre",
     "emotion_arc": ["curiosite", "tension", "emerveillement", "melancolie", "sagesse"],
     "essence": "Un chêne millénaire t'enseigne une vérité que les hommes ont oubliée.",
     "hook": "L'écorce s'ouvre comme une bouche, et le bois parle d'une voix qui sent la résine et le siècle.",
     "length_pref": [15, 17, 21, 25], "twist_pattern": "wisdom_arc"},
    {"id": "mist_wanderer", "name": "Le Vagabond de Brume", "pole": "Liminal",
     "emotion_arc": ["curiosite", "tension", "peur", "fascination", "sagesse"],
     "essence": "Tu te perds dans une brume qui n'est pas faite d'eau, et tu trouves ce que tu ne cherchais pas.",
     "hook": "La brume monte des racines, pas du sol. Elle se referme derrière toi comme une porte.",
     "length_pref": [11, 15, 17, 21], "twist_pattern": "lost_then_found"},
    {"id": "forest_trial", "name": "L'Épreuve de la Forêt", "pole": "Chaos",
     "emotion_arc": ["tension", "peur", "colere", "espoir", "sagesse"],
     "essence": "Un péril physique t'exige de prouver ta volonté ou de céder à ta peur.",
     "hook": "Les ronces se cabrent comme des serpents. Le sentier devient gorge, puis fauve.",
     "length_pref": [15, 17, 21, 25], "twist_pattern": "physical_test"},
    {"id": "forgotten_ritual", "name": "Le Rite Oublié", "pole": "Ordre",
     "emotion_arc": ["curiosite", "emerveillement", "tension", "fascination", "sagesse"],
     "essence": "Tu redécouvres une pratique ancestrale et tu dois choisir de l'accomplir ou de la laisser dormir.",
     "hook": "Sept pierres dressées dans la mousse. Six portent un ogham. La septième attend la tienne.",
     "length_pref": [15, 17, 21, 25], "twist_pattern": "ritual_completion"},
    {"id": "hidden_sanctuary", "name": "Le Sanctuaire Caché", "pole": "Liminal",
     "emotion_arc": ["curiosite", "emerveillement", "espoir", "melancolie", "sagesse"],
     "essence": "Tu trouves un refuge paisible qui te guérit, mais quitter ce lieu coûte plus que rester.",
     "hook": "Une clairière baignée d'or pâle. Le temps y semble respirer plus lentement.",
     "length_pref": [11, 15, 17], "twist_pattern": "calm_decision"},
    {"id": "beast_encounter", "name": "La Bête Cornue", "pole": "Chaos",
     "emotion_arc": ["tension", "peur", "fascination", "espoir", "sagesse"],
     "essence": "Un animal ou une créature te confronte. Tu lis ses yeux et tu choisis qui tu es.",
     "hook": "Un cerf blanc se dresse au milieu du chemin. Ses bois portent des os accrochés.",
     "length_pref": [11, 15, 17, 21], "twist_pattern": "wild_communion"},
    {"id": "druid_lineage", "name": "La Lignée des Druides", "pole": "Ordre",
     "emotion_arc": ["curiosite", "emerveillement", "melancolie", "fascination", "sagesse"],
     "essence": "Tu apprends qu'un druide d'autrefois a marqué cet endroit, et qu'il t'attend.",
     "hook": "Un nom est gravé dans l'écorce d'un hêtre. Le tien. Mais l'inscription date d'un siècle.",
     "length_pref": [17, 21, 25], "twist_pattern": "ancestral_echo"},
    {"id": "threshold_crossing", "name": "Le Passage des Seuils", "pole": "Liminal",
     "emotion_arc": ["curiosite", "fascination", "tension", "peur", "emerveillement", "sagesse"],
     "essence": "Tu franchis sans le savoir une frontière entre deux mondes, et tu reviens transformé.",
     "hook": "Tu poses le pied au-delà d'une racine. L'air change de poids. Tu n'es plus dans la même forêt.",
     "length_pref": [17, 21, 25], "twist_pattern": "transformation"},
]

# ═══════════════════════════════════════════════════════════════════════════════
# 2. PROSE FRAGMENTS — hand-crafted druidic premises per archetype
#    Each fragment is 3-5 sentences. The generator picks fragments to compose
#    unique 12-20 sentence scenario premises (opening + middle + closing).
# ═══════════════════════════════════════════════════════════════════════════════

OPENING_FRAGMENTS = {
    "druidic_awakening": [
        "Le jour décline, et tu sens que la forêt a appris ton nom. Quelque chose te suit sans bruit, et ce n'est ni hostile, ni doux : c'est simplement vrai. Tu poses ta main sur un tronc et l'écorce te répond d'une chaleur qui n'a rien d'un feu. Tu comprends, sans qu'on te le dise, que tu n'es plus seulement un voyageur.",
        "Les fougères s'écartent à ton passage et se referment plus serrées derrière toi. Un parfum d'humus mouillé monte à chaque pas, comme si la terre te respirait. Tu portais une question depuis des jours, et voici qu'elle s'allège sans réponse. La forêt n'enseigne pas avec des mots.",
        "Une lumière oblique perce la canopée. Elle ne tombe pas en faisceau : elle dessine un cercle parfait sur la mousse, et le cercle attend. Tu n'as jamais marché ici, et pourtant tes pieds savent où poser. Quelque chose en toi se redresse, qui dormait depuis longtemps.",
    ],
    "korrigan_trickery": [
        "Un rire éclate derrière un buisson. Tu te retournes : rien. Mais ta gourde a disparu, et un caillou rond la remplace dans ta poche. Tu sais ce que sont les korrigans — petits, malins, jamais méchants pour rien — et tu sais qu'ils te testent.",
        "Les ronces se sont écartées trop facilement. Tu avances et la forêt se referme sur un chemin trop droit pour être naturel. Au bout, une assiette de pain attend sur une souche. Le pain est chaud. Personne en vue.",
        "Tu entends qu'on chuchote ton nom à l'envers. Tu te tournes vers le son, et le son recule d'un pas exact. Un éclat de rire fuse. Les korrigans n'ont pas de visage, mais ils ont des intentions, et celles-ci sont curieuses de toi.",
    ],
    "ancient_oak_counsel": [
        "Le chêne se dresse au milieu de la clairière comme une statue plus vieille que les murs. Sa couronne couvre un quart du ciel. À sa base, sept pierres lichénifiées, et entre elles, un silence qui pèse comme un secret. Tu sais qu'il faut s'asseoir, et tu t'assieds.",
        "L'écorce porte des cicatrices nettes : des éclairs, des feux, des coups de hache. Aucun n'a tué l'arbre. Tu sens, en posant ta main, un pouls long de plusieurs minutes. Il te parle, mais pas avec des mots — avec des images qui montent depuis tes propres souvenirs.",
        "Un vieillard est assis contre le tronc. Il a une barbe de mousse et des yeux d'eau de pluie. « Tu es venu », dit-il sans surprise. « Assieds-toi. » La voix sort de l'arbre autant que de l'homme, et tu ne sais plus qui parle.",
    ],
    "mist_wanderer": [
        "La brume monte des racines, pas du sol. Elle est blanche, dense, légère, et elle a une direction. Elle ne te bouche pas la vue — elle te bouche le temps. Tu marches dix pas, et trois jours passent. Tu marches dix autres pas, et tu reviens au début.",
        "Tu cherchais ton chemin. La brume cherchait quelqu'un. Elle te trouve, t'enveloppe, et te dit doucement : « par ici ». Tu ne sais plus où est le sud. Tu sais juste qu'il faut continuer.",
        "Les arbres flottent comme des îles dans l'air laiteux. Leurs cimes émergent, leurs troncs disparaissent. Tu lèves la tête et tu vois une lune en plein jour. Elle est mauve. La brume sourit, sans bouche.",
    ],
    "forest_trial": [
        "Les ronces se cabrent comme des serpents devant toi. Le chemin que tu suivais s'est refermé en gorge épineuse, et la seule voie est à travers. Ton sang bat à tes tempes. Tu sais que la forêt teste ta volonté avant ta force.",
        "Un grondement bas roule sous la mousse. Le sol vibre, et trois sangliers énormes émergent des fougères. Leurs yeux sont rouges, leurs défenses jaunies par l'âge. Ils ne chargent pas encore. Ils attendent ta décision.",
        "Un froid sec descend d'un coup. Tes mains tremblent. Tu réalises que la lumière a baissé de quatre tons sans que le soleil bouge. La forêt te montre les dents. Tu dois choisir : reculer en perdant ce que tu cherchais, ou avancer en perdant peut-être plus.",
    ],
    "forgotten_ritual": [
        "Sept pierres dressées dans la mousse forment un cercle imparfait. Six portent un ogham gravé. La septième est vierge, mais polie comme par une main récente. À ton approche, les six oghams émettent une lueur faible. La septième attend.",
        "Un fragment de céramique brisée dans les feuilles : un bol rituel, peut-être druidique, peut-être plus ancien. Les motifs y dessinent une sphère traversée d'une ligne, et tu sais — sans savoir comment — qu'il manque une offrande à cet endroit précis.",
        "Au pied d'un if noir, un autel de pierre nue. Dessus, un crâne d'animal — biche ? — propre, ancien, attendant. Les feuilles autour de l'autel forment un cercle parfait alors que partout ailleurs elles sont éparses. Quelque chose veut s'achever ici.",
    ],
    "hidden_sanctuary": [
        "Une clairière baignée d'or pâle s'ouvre derrière un rideau de fougères. L'air y est tiède, le silence dense, le temps plus lent. Tu t'assieds sans le décider, et tes épaules se détendent pour la première fois depuis des jours. Tu pourrais rester ici longtemps.",
        "Un ruisseau coule entre des pierres mousseuses. L'eau est si claire que tu vois le sable au fond comme à travers du verre. Tu y plonges les mains, et la fatigue s'en va. Tu lèves la tête : un cerf te regarde sans peur, et tu sais que tu es en sécurité.",
        "Une cabane de bois grise, presque effacée par le lierre. La porte n'est pas fermée. Dedans, un feu éteint, un lit propre, une table avec du pain et une cruche d'eau. La cabane attendait quelqu'un. Et ce quelqu'un, ce soir, c'est toi.",
    ],
    "beast_encounter": [
        "Un cerf blanc se dresse au milieu du chemin. Ses bois portent des os accrochés — petits, blancs, polis par le frottement des branches. Il ne bouge pas. Il te regarde comme s'il te connaissait, et tu sens qu'il ne te jugera pas.",
        "Une louve sort d'un fourré, suivie de trois louveteaux. Elle s'arrête à dix pas. Ses yeux sont jaunes, ses oreilles dressées, mais sa posture n'est pas celle de la chasse. Elle t'a senti venir. Elle a décidé que tu n'étais pas une menace. Ou pas encore.",
        "Un sanglier antique, énorme, mousse poussant entre ses soies. Il broute calmement à dix mètres. Quand il lève la tête, ses yeux sont tristes, pas féroces. Tu réalises qu'il est blessé. Une lame rouillée dépasse de son flanc.",
    ],
    "druid_lineage": [
        "Un nom est gravé dans l'écorce d'un hêtre. Le tien. Mais l'inscription date d'un siècle, lichénifiée, presque effacée. À côté, une seconde main a ajouté plus tard : « il reviendra ». Tu ne sais pas si tu dois rire ou trembler.",
        "Une stèle de granit penchée par le temps. Quatre noms y sont gravés, tous précédés du mot « druide ». Le dernier nom s'arrête à la moitié — comme si le graveur avait été interrompu. Tu sens, à le toucher, que ce nom interrompu a quelque chose à voir avec toi.",
        "Un vieil homme — vraiment vieil, peau de parchemin — est assis sur une racine. Il porte une cape de feuilles cousues. « Tu as les yeux de ta grand-mère », dit-il. « Elle s'est arrêtée ici, autrefois. Elle n'a pas voulu finir le rite. »",
    ],
    "threshold_crossing": [
        "Tu poses le pied au-delà d'une racine épaisse. L'air change de poids. Tu te retournes : la racine est toujours là, mais le sentier que tu as suivi n'existe plus derrière elle. La forêt continue, mais elle n'est plus la même.",
        "Tu traverses un voile de feuilles tremblantes et le bruit du monde s'éteint. Plus d'oiseaux, plus de vent — un silence si complet qu'il a une épaisseur. Tu entends ton propre cœur, et il bat plus lentement qu'avant.",
        "Une porte sans cadre se dresse entre deux ifs. Un linteau de pierre, un seuil de mousse, rien autour. Tu peux la contourner sans difficulté. Mais quelque chose en toi exige que tu passes par elle.",
    ],
}

MIDDLE_FRAGMENTS = {
    "druidic_awakening": [
        "Tu poursuis ton chemin, et chaque pas semble enlever une couche d'inutile. Le bruit de tes propres pensées s'apaise. Tu réalises que tu n'écoutes plus la forêt — tu la lis. Cette compétence n'était pas en toi hier.",
        "Un oiseau te suit de branche en branche, sans s'envoler. Il chante une mélodie courte, qu'il répète. Tu t'arrêtes pour l'écouter. Au cinquième tour, tu entends — sous le chant — une syllabe humaine. Puis deux. Puis ton prénom.",
        "Une présence marche à ton côté sans corps. Tu ne la vois pas, tu la sens — chaude, attentive, ancienne. Elle ne te veut rien de mal. Elle t'apprend, par sa seule présence, ce que c'est qu'avoir un mentor invisible.",
    ],
    "korrigan_trickery": [
        "Trois sentiers s'ouvrent devant toi, identiques. Sur chacun, à la même distance, un petit cailloux rond peint en blanc. Tu sais que les korrigans aiment les choix. Tu sais aussi qu'ils trichent.",
        "Un panier de pommes apparaît sur une souche. Elles sont rouges, parfaites, brillantes. Tu n'as pas faim, et c'est ce qui te sauve : tu reconnais le piège du don gratuit. Un rire fuse derrière un fourré.",
        "Un enfant t'appelle à l'aide depuis le bord d'un ravin. Sa voix est juste. Sa peur sonne vraie. Mais ses pieds ne touchent pas le sol — ils flottent à un centimètre. Tu hésites. Tu hésites une seconde de trop pour les korrigans.",
    ],
    "ancient_oak_counsel": [
        "Le chêne parle, mais pas avec sa voix. Il parle avec la tienne, en projetant dans ton esprit les mots que tu aurais dû dire à quelqu'un, autrefois, et que tu as tus. Tu pleures sans savoir pourquoi.",
        "L'arbre te montre, en visions courtes, la racine de ta blessure principale. Tu y reconnais ton père, ta mère, ou ce moment d'enfance où tu as cessé de croire. Le chêne ne juge pas. Il te tend l'image, et tu fais ce que tu veux avec.",
        "Une lumière dorée s'écoule de l'écorce et coule sur tes paumes. Elle ne brûle pas. Elle s'absorbe. Tu sens, après, que tu sais une chose que tu ignorais : un nom, une date, une vérité froide sur quelqu'un que tu aimes.",
    ],
    "mist_wanderer": [
        "La brume t'ouvre un passage et tu suis sans réfléchir. Tu marches sur une corniche que tu n'aurais jamais empruntée à découvert. À mi-chemin, la brume se dissipe : tu réalises que tu es à trente mètres au-dessus du vide, et la peur te frappe d'un coup.",
        "Tu débouches dans une clairière où le brouillard forme des silhouettes — un cheval, un homme barbu, une vieille femme. Aucune ne te voit. Elles vivent dans une scène que la brume rejoue depuis longtemps. Tu comprends, en regardant, que ces gens sont morts ici, autrefois.",
        "La brume t'oublie. D'un coup. Tu te retrouves seul, debout, dans un endroit clair, à côté d'un pommier en fleurs. C'est le printemps. C'était l'automne quand tu es entré dans le brouillard. Une voix dans ta tête te dit : « trois mois ». Tu ne sais pas si elle plaisante.",
    ],
    "forest_trial": [
        "Tu serres les dents et tu charges. Les ronces se referment sur tes bras, tes jambes, ton visage. Tu hurles. Tu avances quand même. Au bout du tunnel d'épines, tu sors entaillé, sanglant, mais entier — et la forêt te respecte un peu plus.",
        "Tu choisis la fuite. Tu cours sans regarder en arrière. Tu sens, dans le bruit de tes propres pas, que tu ne perds pas la face : tu apprends ta limite. Quand tu t'arrêtes enfin, à un kilomètre de là, le silence te dit que la forêt a noté ta sagesse.",
        "Tu négocies. Tu parles au péril comme à un être doué de raison. Tu décris ce que tu cherches, pourquoi, ce que tu offrirais en échange du passage. Le péril ne te répond pas en mots — il s'écarte, lentement, et tu passes sans une égratignure.",
    ],
    "forgotten_ritual": [
        "Tu cherches dans ta mémoire l'ogham qui correspondrait. Aucun ne te vient. Tu prends donc le couteau dans ta ceinture et tu graves le tien — une marque que tu n'avais jamais pensé à inventer. La pierre l'accepte.",
        "Tu fais brûler un brin d'armoise sur l'autel. La fumée monte droit, ne se disperse pas. Au-dessus de l'autel, une forme prend corps dans la fumée : un visage, peut-être féminin, qui te regarde sans te juger.",
        "Tu hésites à accomplir le rite. Quelque chose te retient. C'est sage : ce rite n'est pas pour toi, mais pour quelqu'un qui viendra après. Tu retournes le bol, l'enfonces dans la mousse, et tu poursuis ton chemin.",
    ],
    "hidden_sanctuary": [
        "Tu dors d'un sommeil sans rêves. Tu te réveilles plus jeune — pas dans le corps, mais dans la tête. Tu retrouves cette légèreté que tu pensais perdue. Tu te demandes combien de jours sont passés, et tu décides de ne pas demander.",
        "Tu manges du pain qui n'a pas le goût du pain. Il a le goût d'un souvenir d'enfance — celui que tu chéris le plus. Tu pleures un peu, sans tristesse. La clairière respecte tes larmes.",
        "Un autre voyageur arrive. Plus vieux, plus brisé que toi. Tu lui cèdes ta place sans hésiter. Le sanctuaire t'a guéri ce qu'il fallait. La clairière, elle, ne le verra pas comme un sacrifice — elle le verra comme une chaîne qui se prolonge.",
    ],
    "beast_encounter": [
        "Tu baisses lentement les armes que tu n'as pas. Tes mains ouvertes parlent à la bête mieux qu'aucun mot. Elle s'approche, te renifle, te marque le front d'une caresse de museau. Tu sais que la forêt vient de t'admettre.",
        "Tu fuis. La bête te suit sur dix mètres, puis s'arrête. Elle ne voulait pas te chasser : elle voulait te tester. Tu réalises trop tard que tu as raté quelque chose d'important. Mais tu vis.",
        "Tu approches en chantant. Pas une chanson — une note, longue, basse, tenue. La bête écoute. Elle ferme les yeux. Tu réalises, en la regardant ainsi apaisée, que ces créatures de la forêt portent un poids que tu ne comprends pas encore.",
    ],
    "druid_lineage": [
        "Le vieil homme te raconte ta grand-mère. Pas comme un parent — comme une druidesse. Tu apprends, dans son récit, qu'elle a refusé la chose qu'on lui demandait, et que ce refus t'a sauvé, toi qui n'étais même pas né.",
        "Tu lis sur la stèle les noms des druides qui t'ont précédé dans cette lignée que tu ignorais. Quatre noms, quatre vies, quatre fins. La cinquième entaille — incomplète — semble t'attendre, et tu hésites à savoir si tu veux la finir.",
        "Une vision te traverse : un homme qui te ressemble, vêtu d'une cape verte, debout au même endroit, il y a deux cents ans. Il te regarde à travers le temps et il sourit. « Bienvenue », semble-t-il dire. « Tu n'es pas seul. »",
    ],
    "threshold_crossing": [
        "Tu marches dans cet ailleurs qui ressemble à la forêt mais n'est pas elle. Les couleurs sont plus vives, les odeurs plus précises, les bruits plus chargés. Tu sens, à respirer, que tu prends en toi quelque chose qui ne se rend pas.",
        "Tu rencontres ton propre reflet sur un étang sans eau — juste l'image, sans support. Elle te parle. Elle t'apprend une chose que tu ne savais pas sur toi. Elle s'efface ensuite, doucement, comme un dessin sur du sable.",
        "Tu trouves, au cœur de cet endroit étrange, un seul oiseau perché sur une branche d'or. Il chante une note, une seule, qu'il tient longtemps. Quand il s'arrête, tu sais comment revenir. Mais tu sais aussi que tu ne reviendras jamais tout à fait.",
    ],
}

# ═══════════════════════════════════════════════════════════════════════════════
# v7.7.22c — INTRO FRAGMENTS : contextualize the run for the player.
# Lore : tu es un jeune druide en initiation, le monde se présente comme réel
# (la dimension simulation reste cachée — pas de 4e mur ici). 4 intros par
# archétype × 10 archétypes = 40 intros uniques, chacun 6-8 phrases.
# ═══════════════════════════════════════════════════════════════════════════════

INTRO_FRAGMENTS = {
    "druidic_awakening": [
        "Tu es un jeune druide, à peine sorti des années d'apprentissage. Ton maître t'a confié ta première vraie marche dans le bois sacré de Brocéliande : seul, sans carte, sans consigne précise — sinon celle d'écouter. Tu portes une cape de lin écru, un couteau d'os à la ceinture, et la mémoire vive de tout ce qu'on t'a appris. Tu sais que Brocéliande choisit ses élèves autant qu'on la choisit. Tu sais aussi que les premiers pas comptent — la forêt te jaugera tout le long. Pour la première fois, tu poses le pied sur la mousse en sentant que ce n'est pas un sol comme un autre.",
        "Le clan t'a vu partir au lever du jour. Personne ne t'a accompagné : c'est l'usage. Un jeune druide doit affronter Brocéliande sans béquille, et tes Anciens t'ont dit que la forêt parle d'autant plus fort que tu y entres en silence. Tu marches depuis trois heures quand le sentier s'efface sous tes pieds, remplacé par un tapis de fougères qui ne porte aucune trace. Tu prends une grande inspiration. Tu sais que c'est maintenant que la véritable initiation commence — et tu sais aussi que tu n'as pas le choix d'avoir peur, seulement de continuer.",
        "Ton nom druidique te sera donné à la fin de cette marche, si tu reviens digne. Pour l'instant tu n'es qu'un apprenti aux mains tachées d'encre runique, à l'esprit plein de noms qui ne t'appartiennent pas encore. Tu portes au cou un pendentif de gui que ta grand-mère t'a noué le matin du départ. « Brocéliande ne ment pas », t'a-t-elle dit, « mais elle ne dit rien qu'à celui qui écoute deux fois. » Tu y penses en avançant, et tu te demandes ce que cela veut dire vraiment.",
        "Trois nuits, tu as rêvé de cette forêt avant d'y entrer. Trois nuits du même rêve : un cercle parfait de lumière sur la mousse, et toi assis au centre, sans peur. Ton maître a souri quand tu lui as raconté. « Va », a-t-il dit, « la forêt t'appelle. » Tu n'as pas demandé pourquoi tu rêvais avant de connaître l'endroit. Tu sais maintenant que certaines choses se vivent à l'envers — d'abord en songe, puis en pas réels.",
    ],
    "korrigan_trickery": [
        "Tu es un jeune druide, et les Anciens t'ont averti : Brocéliande regorge de korrigans, ces petits êtres facétieux que les druides reconnaissent comme nos cousins de l'autre versant. « Ne les traite pas en ennemis », a dit ton maître, « ni en amis. Ils sont autres. » Tu portes dans ta besace un peu de sel, un peu de pain, et une fiole de lait — les trois offrandes qui les apaisent. Tu sais qu'aujourd'hui, en marchant dans le bois sacré, tu vas probablement les croiser. Tu n'as pas peur. Tu es seulement curieux de voir si tu sauras tenir leur jeu.",
        "Les korrigans ne tuent pas. Voilà ce qu'on t'a répété tout l'hiver autour du feu. « Ils piègent, ils volent, ils rient, mais ils ne tuent pas — sauf ceux qui méritent vraiment. » Tu es jeune, sans grand péché à ton actif, et tu te crois protégé par ta candeur. Tu entres dans Brocéliande en sifflotant. C'est probablement la première erreur de ta journée. Quelque part, en t'écoutant siffler, un korrigan vient d'éclater de rire dans une racine, et il décide que tu seras son passe-temps.",
        "Ton oncle a perdu trois jours dans Brocéliande quand il était jeune — pris par les korrigans, dit-il, qui l'ont fait tourner en rond autour d'un même chêne en lui faisant croire qu'il avançait. Tu y as repensé toute la nuit avant de partir. Maintenant que tu poses le pied sur la mousse, tu te promets de ne pas tomber dans le piège. Tu prends des repères, tu marques l'écorce de ton couteau. Les korrigans te regardent faire. Ils trouvent ça touchant, et un peu vain — ils savent déjà comment ils vont s'y prendre.",
        "On t'a confié une mission précise : retrouver une plante rare qui ne pousse qu'au cœur de Brocéliande. Ton maître a besoin d'elle pour un baume qui sauvera trois villages malades. Tu es donc en marche depuis l'aube, l'esprit concentré, le pas pressé. C'est dans cet état d'esprit — affairé, sérieux, un peu solennel — que les korrigans te repèrent. Et tu n'as pas idée du nombre de détours qu'ils vont t'imposer avant de te laisser cueillir cette plante.",
    ],
    "ancient_oak_counsel": [
        "Tu es un jeune druide, et ce matin ton maître t'a dit ces mots simples : « Va voir le Chêne. Il t'attend. » Tu n'as pas demandé lequel. Il n'y en a qu'un, à Brocéliande, à qui on rend visite ainsi — un chêne si ancien que sa couronne couvre un quart du ciel, et que les druides ne se souviennent plus d'un temps où il n'aurait pas été là. Tu marches vers lui depuis trois heures. Tes mains tremblent un peu. Tu sais que le Chêne ne convoque pas les apprentis sans raison, et tu te demandes laquelle est la tienne.",
        "Le clan a tenu conseil hier soir. Ils ont décidé que tu étais prêt — pas pour passer ta cérémonie d'élévation, mais pour aller seul devant le Chêne Ancien et entendre ce qu'il aurait à te dire. C'est rare. Très rare. Ton maître t'a serré l'épaule au moment du départ, sans un mot. Tu marches maintenant avec dans la poitrine un mélange de fierté et de trac qui te coupe à moitié le souffle. Le Chêne sait qui tu es. C'est la seule chose que tu sais de lui.",
        "Tu rentres d'une longue marche infructueuse dans une autre partie de la forêt quand, soudain, tu sens que tes pieds ne te mènent plus là où tu pensais. Ils te tournent vers une clairière que tu n'avais pas prévue. Tu obéis — un jeune druide apprend vite à ne pas contredire ce qui le guide sans bruit. Au bout du chemin, tu reconnais la couronne immense d'un chêne dont on t'a parlé toute ton enfance. Il t'a fait venir. Tu ne sauras jamais pourquoi exactement.",
        "Ton grand-père, druide avant toi, t'a parlé du Chêne sur son lit de mort. « Il y a un arbre, à Brocéliande », a-t-il dit, « tu sauras quand y aller. Ne précipite rien. Il appellera. » Tu avais douze ans. Tu en as maintenant dix-neuf. Ce matin, en te rasant, tu as su que c'était aujourd'hui. Tu n'as rien dit à personne, tu as pris ton bâton, et tu as marché. Le Chêne, lui, le savait depuis longtemps.",
    ],
    "mist_wanderer": [
        "Tu es un jeune druide, et tu connais bien les brumes de Brocéliande pour les avoir traversées plusieurs fois en compagnie de ton maître. Mais aujourd'hui c'est ta première brume en solo, et la consigne est simple : entres-y volontairement, marches-y une journée, ressors-en. Pas pour rapporter une chose — pour montrer que tu sais tenir ton esprit sous la pression du flou. Tu approches du voile blanc qui flotte entre deux ifs. Il monte lentement, comme une respiration de pierre. Tu inspires profondément et tu poses le premier pied dedans.",
        "Les anciens disent que la brume de Brocéliande mange le temps. Tu as toujours pris ça pour une métaphore. Tu es jeune, tu es rationnel — pour un druide — et tu n'as jamais eu de raison de douter d'une heure de marche. Mais ton maître a insisté : « Va dans la brume seul. Reviens-moi en me disant ce que tu as compris. » Tu obéis donc, comme tu obéis toujours. Ce que tu vas comprendre, tu n'es pas pressé de le découvrir.",
        "Tu n'aurais jamais dû t'aventurer dans cette zone précise de Brocéliande sans guide — c'est ce que dit la règle. Mais tu as suivi un cerf blessé pendant deux heures, et le cerf t'a mené là, au seuil d'un brouillard qui n'a pas l'air honnête. Tu pourrais reculer. Tu sais que tu pourrais reculer. Tu ne le fais pas. Le cerf a disparu dans la brume, et quelque chose en toi exige que tu le suives. Tu y entres avec la légère certitude que tu te le reprocheras peut-être plus tard.",
        "Tu as toujours aimé les brumes. Petit, tu te perdais dans le brouillard de la lande près du village, et tu en revenais transformé — apaisé, comme nettoyé. Ton maître a remarqué cette affinité tôt. « Tu es un enfant du seuil », t'a-t-il dit, « Brocéliande aura beaucoup à te montrer. » Aujourd'hui, devant un voile blanc qui monte des racines, tu sens cette vieille familiarité te chatouiller la poitrine. Tu ne le sais pas encore, mais cette brume-ci est différente des autres.",
    ],
    "forest_trial": [
        "Tu es un jeune druide, et le clan attend de toi des preuves. Les Anciens t'ont prévenu : pour être reconnu comme druide à part entière, il te faut survivre à une marche dans la part rude de Brocéliande — celle où les ronces s'élèvent à hauteur d'homme et où le sentier se referme dans ton dos. Tu n'as pas peur, exactement. Tu as la peur saine du jeune qui sait que sa peur est utile. Tu portes un long bâton, un couteau aiguisé, et la prière silencieuse d'en sortir grandi. La forêt, elle, ne sait pas encore ce qu'elle pense de toi.",
        "Tu marches dans Brocéliande depuis six heures quand le sentier devient hostile. Tu le sens dans tes mollets d'abord — quelque chose pèse plus lourd. Puis dans l'air, qui se fait sec. Puis dans le silence, qui s'épaissit. Tu sais ce que c'est : la forêt te teste. Ton maître t'a parlé de ces zones — il les a appelées « les seuils âpres ». On n'y entre que prêt. Tu n'es pas sûr de l'être, mais tu es là, et tu sais que reculer n'est pas une option si tu veux te respecter au retour.",
        "On a perdu deux apprentis l'année dernière, dans Brocéliande. Le clan en parle peu, mais tu as entendu les murmures. Ils ne sont pas morts — ils sont revenus brisés, incapables de redire ce qu'ils avaient vu. Tu y penses chaque fois que tu poses un pied devant l'autre depuis ce matin. Tu sais que la forêt n'épargne pas tout le monde. Tu sais aussi que ton maître t'a jugé prêt — et qu'il ne se trompe jamais sur ce point. Tu décides de lui faire confiance, même quand toi, tu doutes.",
        "Tu portes une promesse au creux de la poitrine : revenir à ta sœur cadette, qui t'attend au village avec l'inquiétude qu'on a pour un grand frère qui part seul. C'est cette promesse, plus que la mission elle-même, qui te tient debout depuis l'aube. La forêt, devant toi, commence à montrer ses dents. Tu serres ton bâton un peu plus fort. Tu n'as pas le luxe d'échouer, et tu le sais. Mais Brocéliande, elle, ne fait pas de promesses aux apprentis.",
    ],
    "forgotten_ritual": [
        "Tu es un jeune druide, et tes lectures dans la grotte des manuscrits ont éveillé en toi une curiosité qui ne te lâche plus. Un rite, vieux de plusieurs siècles, n'a plus été accompli depuis la mort de la dernière druidesse qui le savait. Tu as découvert son nom hier soir, par hasard, dans un fragment de cuir runique. Ce matin, sans avertir personne, tu es parti à la recherche du lieu où ce rite se pratiquait — quelque part dans le cœur de Brocéliande. Tu n'es pas certain de ce que tu vas y trouver. Tu sais juste que tu dois aller voir.",
        "Le clan t'a chargé d'une enquête : retrouver le cercle de pierres où, il y a très longtemps, les druides accomplissaient le Rite des Sept Souffles. Les détails du rite ont été perdus, mais le lieu, dit-on, existe encore. Tu marches depuis l'aube avec un parchemin esquissé par ton maître. Tu sais que tu cherches quelque chose que tes propres yeux n'identifieront peut-être pas. Tu sais aussi que ce que tu trouves, parfois, te trouve en retour.",
        "Ton maître t'a confié un secret : il y a, quelque part dans Brocéliande, un autel oublié où chaque jeune druide de la lignée venait jadis offrir son premier serment. Cette tradition s'est perdue, et toi, tu es libre de la retrouver. « Pas obligé », a dit ton maître. « Mais possible. Et beau. » Tu marches maintenant avec dans la poche un caillou poli que ton père t'a donné — l'offrande que tu envisages de déposer, si tu trouves l'autel. Si tu ne le trouves pas, le caillou reviendra avec toi, ce qui ne sera pas une honte.",
        "Tu as vu, dans une vision il y a trois jours, six pierres dressées dans la mousse autour d'un emplacement vide. Six oghams, et la septième pierre nue. Tu n'as pas su quoi en faire. Ton maître t'a écouté, hoché la tête lentement, et dit : « Va voir si c'est réel. » Tu marches depuis l'aube. Tu n'as pas idée si la vision était guide ou bien piège. Mais tu sais que les rêves de druide ne se classent pas sans avoir d'abord cherché à les vérifier.",
    ],
    "hidden_sanctuary": [
        "Tu es un jeune druide, et tu marches dans Brocéliande depuis trois jours sans véritable but — un de ces vagabondages que ton maître appelle « la marche du sans-pourquoi », et qui forme autant qu'une mission précise. Tu as l'esprit fatigué, le corps fourbu, et tu commences à te demander si tu vas trouver de quoi te reposer cette nuit. C'est exactement à ce moment, comme souvent, que Brocéliande te tend ce qu'elle a de plus rare : un sanctuaire caché. Tu ne le sais pas encore, mais ton chemin va prendre une tournure que tu n'oublieras jamais.",
        "Le clan a perdu un proche cette saison, et tu portes en toi un chagrin que tes prières n'arrivent pas à apaiser. Ton maître l'a vu — un druide voit ce genre de choses — et il t'a envoyé dans Brocéliande avec une consigne unique : « Trouve un endroit où la forêt te console. » Tu marches depuis hier avec cette consigne flottant dans la tête. Tu ne savais pas qu'on pouvait demander à un bois de consoler quelqu'un. Tu vas apprendre.",
        "Tu cherchais des champignons rares dans une partie de Brocéliande que tu n'avais jamais explorée. Tu as suivi un sentier qui s'est révélé n'être pas tout à fait un sentier — plutôt une suggestion de la forêt elle-même. Tu n'as pas trouvé tes champignons. À la place, tu as senti, à un détour, qu'un endroit te demandait de t'arrêter. Tu n'es pas du genre à ignorer ce genre d'appel. Tu poses ton sac et tu regardes autour de toi, en te demandant ce que la forêt veut te montrer.",
        "Tu es un jeune druide insomniaque depuis des semaines. Quelque chose te ronge, et tu ne sais pas quoi. Ton maître t'a dit ce matin : « Va chercher du silence dans Brocéliande. Il y en a si tu le cherches. » Tu es parti sans grand espoir. Mais voilà, après huit heures de marche, tu sens devant toi un endroit qui semble respirer plus lentement que le reste du bois. Tu approches. Tu poses la main sur le tronc le plus proche, et tu sens, pour la première fois depuis longtemps, que tu pourrais dormir.",
    ],
    "beast_encounter": [
        "Tu es un jeune druide, et ton apprentissage avec les animaux est encore neuf. Tu sais reconnaître les pistes des chevreuils, lire les empreintes des renards, et tu as déjà soigné un faucon blessé que ton maître t'avait confié. Mais aujourd'hui, dans Brocéliande, tu vas faire ta première vraie rencontre avec une créature qui te dépasse — une bête plus mythique qu'animale, dont les Anciens parlent à voix basse. Tu ne sais pas encore qu'elle est là, à cent pas devant toi, et qu'elle t'a senti venir depuis longtemps. Elle attend de voir comment tu vas réagir.",
        "Les bêtes de Brocéliande ne sont pas comme les bêtes de la lande. Les Anciens t'ont prévenu. « Elles ont quelque chose en plus », a dit ton maître. « Pas exactement de l'âme — pas comme la nôtre. Mais quelque chose. Sois respectueux. » Tu marches depuis le matin avec cette consigne au cœur. Tu te demandes ce que tu feras si tu en croises une. Tu vas bientôt savoir. La forêt a déjà décidé du test.",
        "Tu pistes une louve qui aurait tué un mouton de ton village — du moins, c'est ce qu'ont dit les bergers. Tu n'es pas certain qu'elle l'ait fait. Tu sais que les vrais druides ne tuent pas les loups sans avoir d'abord compris ce qui s'est passé. Tu marches donc dans Brocéliande non pas pour exécuter, mais pour comprendre. C'est cette nuance — invisible aux yeux des bergers, claire pour toi — qui va peut-être te sauver la vie aujourd'hui. Ou la lui sauver à elle. Ou les deux.",
        "Une vision, hier soir, t'a montré un cerf blanc aux bois constellés d'os. Tu te réveilles ce matin avec la certitude que tu vas le rencontrer. Tu pars sans rien dire à ton maître — parfois, certaines rencontres ne supportent pas qu'on en parle avant. Tu marches dans Brocéliande avec le cœur qui bat un peu trop vite. Tu n'as pas peur du cerf. Tu as peur de ne pas savoir comment être devant lui. Tu sens, à raison, que ce moment va te marquer.",
    ],
    "druid_lineage": [
        "Tu es un jeune druide, et la veille de partir, ta grand-mère t'a glissé une chose à l'oreille que tu n'as pas comprise : « Si tu trouves un nom gravé dans l'écorce, ne fuis pas — c'est moi qui te le lègue. » Elle a souri, t'a embrassé, et n'a rien voulu expliquer de plus. Tu marches dans Brocéliande depuis ce matin avec sa phrase qui flotte dans ta tête. Tu te demandes si elle parlait au sens propre ou figuré. Tu vas avoir ta réponse plus tôt que prévu.",
        "Le clan tient des chroniques sur tous les druides qu'il a produits depuis dix générations. Ton maître t'a montré ta lignée hier — quatre druides avant toi, en ligne directe : ton père, ton grand-père, ta grand-tante, ton arrière-arrière-grand-père. Tous ont marché dans Brocéliande à ton âge. Tous y ont laissé une trace que la forêt garde. « Va voir si tu trouves la leur », a dit ton maître. « Et la tienne aussi. » Tu pars donc avec dans le sac un crayon de fusain et un parchemin vierge.",
        "Tu n'as jamais connu ton père — il est mort dans Brocéliande quand tu avais deux ans. Le clan parle peu de lui. Tu sais qu'il était druide, qu'il s'appelait Branwen, et qu'il est entré dans le bois un jour de solstice et n'en est jamais ressorti. Ce matin, tu pars à ta première marche solo, en t'autorisant secrètement à chercher quelque chose qui te parle de lui. Ton maître l'a compris sans que tu en parles. Il t'a juste dit, en partant : « Sois prudent. Et écoute. »",
        "Tu as toujours senti, en lisant les vieux manuscrits, qu'une partie de la lignée druidique te concernait sans que tu saches expliquer pourquoi. Hier soir, ton maître t'a tendu une feuille de parchemin et t'a dit : « Va voir si ce nom te dit quelque chose. » Le nom, c'est le tien — mais écrit dans une calligraphie qui date d'au moins un siècle. Tu n'as pas dormi de la nuit. Au matin, tu es parti vers Brocéliande avec le parchemin plié contre ta poitrine, et plus de questions que de réponses.",
    ],
    "threshold_crossing": [
        "Tu es un jeune druide, et ton maître t'a dit ceci : « Aujourd'hui, tu vas passer un seuil. Tu ne sauras pas lequel avant de l'avoir passé. Mais quand ce sera fait, tu le sauras. » Tu marches dans Brocéliande depuis ce matin avec cette phrase qui te trotte dans la tête. Tu cherches le seuil. Tu ne le trouves pas. Ce que tu ne sais pas encore, c'est que les seuils, comme les vraies leçons, viennent à toi quand tu cesses de les chercher. Tu vas cesser bientôt — et le seuil sera là.",
        "Les Anciens disent qu'il existe, dans Brocéliande, des endroits où les mondes se touchent presque. Ils ne sont pas marqués sur les cartes. Ils n'apparaissent qu'à ceux qui en ont besoin, quand ils en ont besoin. Tu as toujours pris ça pour des contes pour apprentis impressionnables. Aujourd'hui, en marchant, tu sens dans l'air une qualité que tu n'avais pas remarquée auparavant — une légèreté, presque une vibration. Tu ne sais pas encore que les contes sont vrais.",
        "Tu as rêvé toutes les nuits de la semaine d'une porte sans cadre, dressée entre deux ifs noirs. Tu te réveillais à chaque fois avec la sensation d'avoir vu quelque chose d'important — sans savoir quoi. Ce matin, ton maître t'a regardé en silence pendant un long moment et t'a dit : « Va. » Tu pars donc dans Brocéliande, certain que tu vas trouver cette porte. Tu es moins certain de savoir si tu vas oser la traverser.",
        "Tu es un jeune druide curieux et les Anciens trouvent que tu poses trop de questions. Hier, devant le feu, tu as demandé : « Mais les autres mondes, vraiment, où sont-ils ? » Ton maître a souri, comme il sourit quand tu poses la bonne question pour de mauvaises raisons. « Va le voir », a-t-il dit. « Brocéliande t'expliquera mieux que moi. » Tu marches maintenant en sachant que tu vas peut-être passer un seuil — et tu te demandes si la curiosité, finalement, n'est pas le plus grand des seuils.",
    ],
}


# ═══════════════════════════════════════════════════════════════════════════════
# v7.7.22c — TWIST FRAGMENTS : mid-route revelation that recontextualizes the
# situation. Inserted at merge points in the branching tree to give "rebondissement".
# ═══════════════════════════════════════════════════════════════════════════════

TWIST_FRAGMENTS = {
    "druidic_awakening": [
        "Tu réalises soudain que ce que tu prenais pour ton intuition d'apprenti est en fait quelque chose de plus ancien, qui passe par toi sans demander la permission. Ton maître t'avait prévenu d'un mot, sans détailler. Tu comprends maintenant pourquoi il n'a pas voulu en dire plus : il fallait que tu le sentes seul.",
        "Une chose t'apparaît, claire comme du verre : la forêt ne t'apprend pas. Elle te ré-apprend. Tout ce que tu vas découvrir ici, tu l'as oublié à un moment dont tu n'as pas le souvenir. Cette révélation te coupe le souffle quelques secondes. Puis tu repars, plus tranquille.",
    ],
    "korrigan_trickery": [
        "Tu comprends à cet instant que les korrigans ne te piègent pas pour te nuire — ils te piègent pour t'apprendre une leçon qu'ils estiment importante. C'est presque touchant. C'est aussi terrifiant, parce que cela veut dire qu'ils te connaissent mieux que tu ne te connais toi-même.",
        "Un détail t'éclate à la figure : tous les pièges des korrigans visent ton orgueil, jamais ton corps. Ils savent que tu es jeune, brillant, sûr de toi — et c'est cela qu'ils chassent. La vraie épreuve commence quand tu acceptes que cette part de toi mérite peut-être d'être taillée.",
    ],
    "ancient_oak_counsel": [
        "Le Chêne te révèle, sans le dire, qu'il connaissait ton grand-père. Et avant lui, ton arrière-grand-mère. Toute ta lignée druidique a posé la main sur son écorce. Tu n'es pas le premier de ta famille à venir lui demander conseil. Cette continuité te transperce.",
        "Tu réalises au milieu de la conversation que le Chêne ne te dit jamais ce que tu dois faire — il te montre ce que tu as déjà décidé sans le savoir. Sa sagesse n'est pas de répondre à ta question, mais de te révéler la réponse que tu portais. Tu sors de là changé sans avoir reçu un seul ordre.",
    ],
    "mist_wanderer": [
        "Tu prends conscience que la brume ne t'égare pas — elle te ramène. Vers où, tu ne sais pas encore. Mais tu sens, à mesure que tu marches, que chaque pas te rapproche d'un endroit que tu as visité une fois, peut-être en rêve, peut-être avant ta naissance, et que tu avais perdu.",
        "Un instant de clarté brise le voile : la brume n'est pas un phénomène de la forêt. La brume est une PRÉSENCE — quelque chose qui pense, qui choisit, qui te guide. Tu ne sais pas si tu dois t'en méfier ou la remercier. Tu décides, pour l'instant, de respecter.",
    ],
    "forest_trial": [
        "Au milieu de l'épreuve, tu comprends une chose que ton maître n'avait pas voulu te dire : la forêt ne teste pas ta force. Elle teste ta capacité à reconnaître quand céder. Les apprentis qui sont revenus brisés n'ont pas échoué par faiblesse — ils ont échoué par excès de bravoure mal placée.",
        "Tu réalises soudain que les ronces, le froid, les bêtes — tout cela n'est qu'un décor. Le vrai péril est en toi : c'est la voix qui te dit de continuer à tout prix, et qui te dit ça parce qu'elle a peur de paraître lâche aux yeux de qui n'est même pas là. Reconnaître cette voix, c'est passer la moitié de l'épreuve.",
    ],
    "forgotten_ritual": [
        "Tu comprends en touchant l'autel que ce rite n'a pas été oublié — il a été enterré, volontairement, par les druides qui t'ont précédé. Pourquoi ? Tu ne sais pas. Mais l'évidence te frappe : reprendre un rite enterré n'est pas un acte neutre. Il faudra que tu acceptes les conséquences.",
        "Un détail révélé par la mousse autour des pierres change tout : le dernier druide à avoir accompli ce rite l'a laissé inachevé délibérément. Il a choisi de ne pas terminer. Tu comprends pourquoi : il a vu quelque chose à mi-rite qui l'a fait reculer. Tu vas peut-être voir la même chose. Tu décides quand même de continuer.",
    ],
    "hidden_sanctuary": [
        "Tu réalises que ce sanctuaire n'apparaît qu'aux druides qui en ont vraiment besoin. Pas à ceux qui le cherchent, pas à ceux qui le méritent — à ceux qui souffrent au point que la forêt ne supporte plus de les voir marcher. C'est humiliant et émouvant à la fois.",
        "Au cœur du calme, une chose te traverse : ce lieu est gardé par quelqu'un. Pas un humain, pas tout à fait un esprit non plus. Une présence qui veille discrètement sur les voyageurs blessés. Tu ne la verras peut-être jamais, mais tu sais maintenant qu'elle existe — et que tu lui dois quelque chose de respectueux.",
    ],
    "beast_encounter": [
        "Tu comprends à la dernière seconde, en regardant l'animal dans les yeux, qu'il n'est pas seulement un animal. Il y a quelqu'un derrière son regard. Pas un humain enfermé dans une bête — autre chose, plus ancien, plus complexe. Tu ne sauras jamais qui exactement. Mais tu sais désormais qu'il existe.",
        "Le détail qui change tout : l'animal te connaît. Pas par hasard. Pas par odeur. Il te connaît parce que vous vous êtes déjà croisés — dans une vie, dans un rêve, dans un sens que tu ne maîtrises pas. Ses yeux te disent : « Te revoilà. » Tu n'as pas de réponse. Tu n'en as pas besoin.",
    ],
    "druid_lineage": [
        "Tu réalises, en lisant les noms gravés, que ta lignée n'est pas linéaire comme tu le pensais. Il y a une bifurcation, quelque part trois générations en arrière. Quelqu'un a refusé la lignée. Quelqu'un d'autre l'a portée pour deux. Cela explique des choses que tu ne savais pas que tu cherchais à comprendre.",
        "Une révélation te transperce : ton père n'est pas mort dans Brocéliande par accident. Il est venu volontairement, pour quelque chose qu'il devait faire — une promesse, un rite, un sacrifice. Tu n'auras jamais les détails. Mais cette nouvelle compréhension change le poids que tu portais à son sujet.",
    ],
    "threshold_crossing": [
        "Au moment de passer le seuil, tu comprends ce que ton maître voulait dire par « tu sauras quand ce sera fait. » Ce n'est pas un événement spectaculaire — c'est une légère, presque imperceptible bascule. Un avant, un après. Et tu sais, avec une certitude tranquille, que tu viens de devenir quelque chose de différent.",
        "Le seuil te révèle ce qui se trouve de l'autre côté : pas un autre monde au sens spectaculaire — une autre façon d'habiter celui-ci. Tu y restes quelques minutes, et tu reviens. Personne ne saura que tu y as été. Mais désormais, chaque chose que tu vivras dans le monde « normal » portera une légère teinte de cet ailleurs.",
    ],
}


CLOSING_FRAGMENTS = {
    "druidic_awakening": [
        "Tu ressors de la forêt avec quelque chose en plus, quelque chose qui n'a pas de mot. Tes pas, sur le chemin du retour, font moins de bruit qu'à l'aller. Tu marches comme si tu connaissais déjà la prochaine étape.",
        "La présence te quitte au bord du bois, là où la forêt rejoint la lande. Tu te retournes. Le vent souffle dans les feuilles d'un certain hêtre, et tu sais que ce hêtre te dira au revoir chaque fois que tu repasseras.",
        "Tu poses ton sac et tu t'assieds. Pour la première fois depuis longtemps, tu n'as besoin de rien. Tu ris doucement, seul, dans le crépuscule.",
    ],
    "korrigan_trickery": [
        "Les korrigans te laissent partir sans avertissement. Une voix d'enfant, derrière toi : « reviens nous voir ». Tu te retournes : personne. Mais ta gourde est pleine d'un vin qu'elle n'avait pas avant.",
        "Tu sors du bois avec un caillou dans la poche. Un caillou rond, lisse, chaud. Il s'éteindra dans quelques jours. Mais tant qu'il est chaud, tu sais que les korrigans pensent à toi.",
        "Tu réalises, en t'éloignant, que tu n'as plus peur d'eux. Tu ne sais pas si c'est un cadeau ou une perte. Le rire qui te suit jusqu'à la lisière ne tranche pas.",
    ],
    "ancient_oak_counsel": [
        "Le chêne se tait. Tu sens, à ses derniers mots, qu'il vient de te donner ce qu'il pouvait. Tu te lèves, courbaturé d'avoir été assis si longtemps. La forêt te paraît plus douce qu'à l'arrivée.",
        "L'écorce se referme. Le vieillard a disparu. Il ne reste sur la pierre qu'un peu de mousse fraîche, dans la forme d'une main d'enfant. Tu touches la mousse, doucement, et tu pars.",
        "Tu portes en toi, maintenant, la vérité froide. Tu la portes comme on porte une lame : avec respect, avec prudence. Tu sais ce que tu vas en faire — mais pas encore tout de suite.",
    ],
    "mist_wanderer": [
        "La brume s'écarte enfin, comme un rideau. Tu retrouves le sentier que tu cherchais. Mais tu n'es plus le même voyageur qu'au début. Quelque chose a été échangé sans contrat.",
        "Tu sors du brouillard à l'endroit même où tu y es entré. Mais le temps n'est plus le même. Tu ne sais pas combien de jours sont passés. La forêt ne te dira pas.",
        "Tu marches longtemps après que la brume se soit dissipée. Tu marches en silence. Tu sais, sans pouvoir l'expliquer, qu'une part de toi est restée là-bas, et qu'elle y restera.",
    ],
    "forest_trial": [
        "Tu sors entaillé mais grandi. La forêt t'a montré ce que tu vaux, et ce que tu vaux, c'est ce que tu choisis dans la peur. Tu marches plus droit après cela.",
        "Tu rentres chez toi sans la chose que tu étais venu chercher. Mais tu rentres avec une chose meilleure : la connaissance de ta limite. Cette limite, désormais, tu ne la franchiras qu'en sachant.",
        "Tu négocies ton passage. La forêt te laisse aller, mais elle te marque — pas sur la peau, plus profondément. Tu le sentiras à chaque décision importante, dans les années qui viennent.",
    ],
    "forgotten_ritual": [
        "Tu accomplis le rite. Quelque chose se ferme — une boucle ouverte depuis des siècles. Tu n'en récolteras pas le fruit, mais quelqu'un, plus tard, le récoltera grâce à toi.",
        "Tu laisses le rite inachevé. Tu sais que c'est la bonne décision. Le rite attendra le bon druide. Ce druide, peut-être, n'est pas encore né.",
        "Tu gravès ton propre ogham. La pierre l'accepte. Tu deviens, par ce geste, l'un des sept gardiens de ce cercle — sans même savoir ce que tu gardes.",
    ],
    "hidden_sanctuary": [
        "Tu quittes la clairière à regret. Mais tu pars guéri, et tu sais que la clairière t'attendra si tu en as besoin. Cette certitude vaut plus que rester.",
        "Tu restes une nuit de plus. Puis une autre. Puis tu te lèves un matin et tu sais que c'est le jour. La clairière ne te retient pas. Elle te bénit en silence.",
        "Tu cèdes la place à un autre voyageur. En partant, tu ne peux pas t'empêcher de regarder en arrière. La clairière est déjà invisible, déjà refermée. Mais quelque chose en toi a appris ce que c'est qu'aider sans rien attendre.",
    ],
    "beast_encounter": [
        "La bête s'éloigne. Tu portes son odeur encore quelques heures — un musc terreux, ancien. C'est un sceau invisible. La forêt te reconnaît désormais comme un sien.",
        "Tu repars sans avoir vu la créature de plus près. Tu marches en sachant que tu as raté quelque chose. Mais tu marches aussi en sachant que tu as choisi la prudence — et cette prudence te servira ailleurs.",
        "Tu retires la lame de la bête blessée. Elle gémit. Tu la soignes avec ce que tu sais — un emplâtre de mousse et d'achillée. Elle te suit du regard quand tu pars. Elle se souviendra de toi.",
    ],
    "druid_lineage": [
        "Tu repars avec une dette envers le passé. Tu ne sais pas encore comment tu la paieras, mais tu sais que tu la paieras. Tu portes maintenant un nom — un vrai, un long, un lignager.",
        "Tu refuses la lignée. Tu graves ton propre nom sur la stèle, à côté des autres, mais barré. La forêt accepte ton choix sans amertume. Tu pars libre.",
        "Tu acceptes l'héritage. Tu sens, dans cette acceptation, le poids d'un siècle qui s'invite dans ta poitrine. Mais aussi la chaleur d'une chaîne qui te tient debout. Tu marches désormais pour plus que toi.",
    ],
    "threshold_crossing": [
        "Tu reviens dans la forêt normale. Tu retrouves les bruits du monde. Mais quelque chose, en toi, voit double désormais. Tu apprendras à vivre avec.",
        "Tu choisis de rester un peu de l'autre côté. Tu ne pourras pas y rester longtemps — ton corps de chair appartient ici — mais tu y reviendras. Tu apprends comment.",
        "Tu passes le seuil dans l'autre sens, plus lentement. Le monde reprend du poids. Tu fais quelques pas et tu réalises que tu marches mieux qu'avant, comme un homme dont les pieds savent où poser même les yeux fermés.",
    ],
}

# ═══════════════════════════════════════════════════════════════════════════════
# 3. CARD SUMMARY TEMPLATES — per CardType × Pole (druidic prose, no anglicisms)
# ═══════════════════════════════════════════════════════════════════════════════

CARD_SUMMARY_TEMPLATES = {
    "NARRATIVE": {
        "Liminal": [
            "Un sentier se brouille devant toi. Une voix sans corps suggère trois directions.",
            "Tu trouves un objet abandonné qui semble t'attendre depuis longtemps.",
            "Une présence invisible marche à ton côté. Tu peux l'accueillir, la chasser, ou la suivre.",
            "Le temps ralentit sans raison. Tu peux profiter, fuir, ou tenter de comprendre.",
            "Une brume porte un parfum d'enfance. Tu peux y rester, l'éviter, ou la respirer profondément.",
            "Un reflet dans une flaque te montre quelqu'un que tu n'es pas. Trois réactions possibles.",
            "Un oiseau te parle dans une langue que tu comprends à demi.",
            "Une lueur danse au-dessus d'une racine. Elle te regarde quand tu approches.",
        ],
        "Ordre": [
            "Une stèle gravée présente trois oghams. Tu dois en honorer un, et un seul.",
            "Un vieux sage te propose une leçon. Tu peux écouter, contester, ou refuser.",
            "Des pierres alignées attendent qu'on les complète. Tu choisis quoi y ajouter.",
            "Un rite ancien te demande un geste. Tu peux l'accomplir, l'adapter, ou le subvertir.",
            "Une voix t'enseigne le nom d'un dieu oublié. Tu décides quoi en faire.",
            "Un druide voyageur te demande de témoigner pour lui devant un cercle.",
            "Un livre relié de cuir vert s'ouvre tout seul à une page précise.",
        ],
        "Chaos": [
            "Des korrigans te volent une chose et te proposent un troc absurde.",
            "Une créature étrange te défie en silence. Tu peux fuir, lutter, ou lui parler.",
            "Une farce te coûte un peu. Tu choisis de rire, de te venger, ou de t'éloigner.",
            "Une apparition te ment ouvertement. Tu peux faire semblant, démentir, ou jouer le jeu.",
            "Un piège évident t'est tendu. Tu peux y entrer en connaissance, l'éviter, ou le retourner.",
            "Un sanglier blessé barre le sentier. Il a l'air de souffrir et d'attendre.",
            "Une voix d'enfant pleure dans un trou que tu ne vois pas.",
        ],
        "Neutre": [
            "Tu trouves trois sentiers, sans signe distinctif. Tu choisis lequel suivre.",
            "Un voyageur croise ta route. Il te demande une faveur sans urgence.",
            "Une source claire t'invite à boire, t'asseoir, ou poursuivre sans pause.",
            "Le vent change. Tu peux abriter, marcher contre, ou suivre sa direction.",
            "Un campement abandonné t'offre des restes. Tu prends, laisses, ou inspectes.",
        ],
    },
    "EVENT": {
        "Liminal": [
            "Un événement saisonnier frappe la forêt : la brume monte d'un coup, tous les sons s'étouffent.",
            "Une bête mythique passe au loin. Tu peux la suivre, la fuir, ou prier qu'elle t'ignore.",
            "Le seuil entre les mondes vacille. Une porte invisible s'entrouvre devant toi.",
            "Une éclipse douce assombrit la canopée pendant trois minutes exactes.",
        ],
        "Ordre": [
            "Une cérémonie druidique se déroule dans une clairière. Tu peux te joindre, observer, ou passer ton chemin.",
            "Les anciens du clan tiennent conseil sous un dolmen. Ils te font signe d'approcher.",
            "Un rite saisonnier exige un participant. Le hasard te désigne.",
            "Un feu sacré allumé il y a un siècle te demande d'être ravivé.",
        ],
        "Chaos": [
            "Une tempête soudaine te plaque au sol. Les korrigans dansent sous la pluie en riant.",
            "Une horde de petits êtres traverse le sentier en sens contraire. Ils paniquent. Pourquoi ?",
            "Un feu prend dans les fougères sans cause apparente. Tu peux l'éteindre, l'observer, ou fuir.",
            "Un essaim de papillons noirs t'environne et te suit sur un kilomètre.",
        ],
        "Neutre": [
            "La nuit tombe plus vite que prévu. Tu dois trouver un abri ou marcher dans l'obscurité.",
            "Un orage approche. Les arbres ploient. Tu choisis ton refuge.",
            "Un brouillard épais te coupe la vue. Tu attends, ou tu avances à l'aveugle.",
        ],
    },
    "SHOP": {
        "Liminal": [
            "Un marchand sans visage propose des objets brumeux : herbes, glands sculptés, fioles vides.",
            "Une vieille te tend une amulette. Elle ne demande pas d'argent — juste un souvenir.",
            "Un troc s'offre : ce que tu portes contre ce que tu n'as pas encore vécu.",
        ],
        "Ordre": [
            "Un druide voyageur te propose des graines rares contre une promesse écrite.",
            "Un sage marchand vend des ouvrages anciens : bois gravés, peaux runiques.",
            "Un guérisseur installe son comptoir : onguents, baumes, conseils. Il accepte le troc.",
        ],
        "Chaos": [
            "Un korrigan camelot t'offre des objets bizarres : un caillou qui chante, une feuille qui se replie.",
            "Une diseuse louche tient un étal : amulettes douteuses, philtres suspects, paroles ambiguës.",
            "Un troc déséquilibré : tu donnes peu, tu reçois beaucoup. Le piège est ailleurs.",
        ],
        "Neutre": [
            "Un voyageur en chemin te propose un échange équitable de provisions.",
            "Un marchand simple, à la lisière du bois, vend du pain, du sel, du fromage.",
            "Un troc honnête : ce que tu n'utilises pas contre ce dont tu manques.",
        ],
    },
    "MERLIN_DIRECT": {
        "Liminal": [
            "Merlin t'interpelle directement. Sa voix sort des branches. Il te demande comment tu vas, vraiment.",
            "Merlin apparaît en transparence dans la brume. Il te tend un parchemin. Tu peux le lire, le brûler, ou le ranger.",
            "Une bulle de silence absolu — Merlin parle. Il te propose une promesse, ou un défi.",
        ],
        "Ordre": [
            "Merlin se manifeste sous la forme d'un vieillard à barbe blanche. Il tient un livre. Il te lit un passage qui te concerne.",
            "Merlin te juge. Il énumère trois de tes choix passés. Tu peux te défendre, te taire, ou contre-attaquer.",
            "Merlin t'ordonne une chose. Tu peux obéir, négocier, ou refuser.",
        ],
        "Chaos": [
            "Merlin rit. Il te montre une chose absurde — une feuille qui flotte à l'envers, par exemple. Il attend ta réaction.",
            "Merlin te triche. Il t'avoue tricher. Il te demande si tu veux jouer quand même.",
            "Merlin te provoque. Il insulte gentiment ta dernière décision. Tu peux rire, te vexer, ou répliquer.",
        ],
        "Neutre": [
            "Merlin commente, neutre. Il te dit ce qu'il observe de toi, sans jugement.",
            "Merlin te pose une question simple sur ton intention. Ta réponse, il l'enregistre.",
        ],
    },
    "PROMISE": {
        "Liminal": [
            "Merlin te promet une chose précieuse — visible plus tard. Il te demande ce que tu donnes en échange.",
            "Un esprit te jure une faveur future. Tu peux accepter ou décliner.",
        ],
        "Ordre": [
            "Un druide te promet un savoir. Il exige une promesse en retour : ne pas le transmettre à n'importe qui.",
            "Un pacte t'est proposé : trois ans de service contre trois ans de protection.",
        ],
        "Chaos": [
            "Un korrigan te jure une vengeance future. Tu peux le calmer, l'ignorer, ou la lui rendre d'avance.",
        ],
        "Neutre": [
            "Un voyageur te demande de promettre de prendre soin d'un objet qu'il te confie.",
        ],
    },
    "RUNE_UNLOCK": {
        "Liminal": [
            "Un ogham nouveau te révèle son nom dans la brume. Tu peux l'apprendre, le refuser, ou attendre.",
        ],
        "Ordre": [
            "Une stèle te livre un Rune-Circuit perdu. Tu peux l'inscrire en toi, ou la laisser dormir.",
        ],
        "Chaos": [
            "Un korrigan, par accident, te montre une rune interdite. Tu peux la mémoriser ou détourner les yeux.",
        ],
        "Neutre": [],
    },
}

CARD_OPTIONS_TEMPLATES = {
    "trio_explore": [
        ("Observer", "observer", "druides"),
        ("Écouter", "ecouter", "anciens"),
        ("Avancer", "avancer", "neutre"),
    ],
    "trio_decide": [
        ("Accepter", "accueillir", "anciens"),
        ("Refuser", "refuser", "ankou"),
        ("Négocier", "negocier", "druides"),
    ],
    "trio_react": [
        ("Affronter", "affronter", "druides"),
        ("Fuir", "fuir", "neutre"),
        ("Apaiser", "apaiser", "niamh"),
    ],
    "trio_offer": [
        ("Donner", "offrir", "druides"),
        ("Prendre", "prendre", "korrigans"),
        ("Échanger", "negocier", "anciens"),
    ],
    "trio_threshold": [
        ("Franchir", "franchir", "niamh"),
        ("Hésiter", "observer", "neutre"),
        ("Reculer", "fuir", "ankou"),
    ],
    "trio_korrigan": [
        ("Jouer leur jeu", "jouer", "korrigans"),
        ("Les défier", "affronter", "druides"),
        ("Les ignorer", "ignorer", "neutre"),
    ],
}

# ═══════════════════════════════════════════════════════════════════════════════
# 4. SCENARIO GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

LENGTHS = [11, 15, 17, 21, 25]

def deterministic_rng(seed_str: str) -> random.Random:
    return random.Random(hash(seed_str) & 0xFFFFFFFF)


def emotion_arc_for_length(emotions, length):
    if length <= len(emotions):
        return emotions[:length]
    result = [emotions[0]]
    middle = emotions[1:-1]
    needed = length - 2
    for i in range(needed):
        result.append(middle[i % len(middle)] if middle else emotions[0])
    result.append(emotions[-1])
    return result


def card_type_for_position(n, total):
    """v7.7.22b adjacency fix : tightened windows so neighboring positions
    can't both match the same special type (no 2 SHOP back-to-back)."""
    if n == total:
        return "MERLIN_DIRECT"
    pos_ratio = n / total
    # Windows tuned so they hit at most one position per length (11..25).
    if abs(pos_ratio - 0.15) < 0.035:
        return "SHOP"
    if abs(pos_ratio - 0.35) < 0.035 or abs(pos_ratio - 0.62) < 0.035:
        return "EVENT"
    if abs(pos_ratio - 0.50) < 0.030 and total >= 21:
        return "MERLIN_DIRECT"
    if abs(pos_ratio - 0.82) < 0.030 and total >= 17:
        return "PROMISE"
    if abs(pos_ratio - 0.75) < 0.025 and total >= 21:
        return "SHOP"   # late respite for long runs
    return "NARRATIVE"


def rarity_for_position(n, total):
    if n == total:
        return "LEGENDAIRE"
    if n == total - 1:
        return "EPIQUE"
    if n == 1:
        return "COMMUNE"
    if n % 5 == 0:
        return "EPIQUE"
    if n % 3 == 0:
        return "RARE"
    return "COMMUNE"


def pole_for_card(archetype_pole, n, total, rng):
    if n == total:
        return archetype_pole
    roll = rng.random()
    if roll < 0.50:
        return archetype_pole
    if roll < 0.65:
        return "Neutre"
    poles = ["Ordre", "Chaos", "Liminal"]
    if archetype_pole in poles:
        poles.remove(archetype_pole)
    return rng.choice(poles) if poles else "Neutre"


def make_card(n, total, archetype, emotion, rng):
    card_type = card_type_for_position(n, total)
    rarity = rarity_for_position(n, total)
    pole = pole_for_card(archetype["pole"], n, total, rng)
    summary_pool = CARD_SUMMARY_TEMPLATES.get(card_type, {}).get(pole)
    if not summary_pool:
        for fallback_pole in [archetype["pole"], "Neutre", "Ordre", "Chaos", "Liminal"]:
            summary_pool = CARD_SUMMARY_TEMPLATES.get(card_type, {}).get(fallback_pole, [])
            if summary_pool:
                pole = fallback_pole
                break
    summary = rng.choice(summary_pool) if summary_pool else "(carte spéciale — narration libre)"
    option_template_keys = ["trio_explore", "trio_decide", "trio_react", "trio_offer"]
    if card_type == "MERLIN_DIRECT":
        option_template_keys = ["trio_threshold", "trio_decide"]
    elif card_type == "SHOP":
        option_template_keys = ["trio_offer"]
    elif pole == "Chaos":
        option_template_keys = ["trio_korrigan", "trio_react"]
    elif card_type == "PROMISE":
        option_template_keys = ["trio_decide"]
    elif card_type == "RUNE_UNLOCK":
        option_template_keys = ["trio_threshold"]
    options_template = CARD_OPTIONS_TEMPLATES[rng.choice(option_template_keys)]
    options = [
        {"label": label, "verb": verb, "primary_faction": faction}
        for label, verb, faction in options_template
    ]
    return {
        "n": n, "type": card_type, "rarity": rarity, "pole": pole,
        "emotion": emotion, "summary": summary, "options": options,
    }


def make_premise(archetype, rng):
    """v7.7.22b — extended premise length to satisfy user spec « 20-100 phrases ».
    Picks 2 openings + 2 middles + 2 closings (distinct sampling without replacement
    when possible) → ~22-28 sentences per premise (above 20 floor)."""
    a_id = archetype["id"]
    op_pool = OPENING_FRAGMENTS[a_id][:]
    md_pool = MIDDLE_FRAGMENTS[a_id][:]
    cl_pool = CLOSING_FRAGMENTS[a_id][:]
    rng.shuffle(op_pool)
    rng.shuffle(md_pool)
    rng.shuffle(cl_pool)
    parts = [op_pool[0]]
    if len(op_pool) > 1:
        parts.append(op_pool[1])
    parts.append(md_pool[0])
    if len(md_pool) > 1:
        parts.append(md_pool[1])
    parts.append(cl_pool[0])
    if len(cl_pool) > 1:
        parts.append(cl_pool[1])
    return "\n\n".join(parts)


# ═══════════════════════════════════════════════════════════════════════════════
# v7.7.22c — INTRO + TWIST + BRANCHING TREE builders
# ═══════════════════════════════════════════════════════════════════════════════

def make_intro(archetype, variant_idx):
    """Lore-aware intro shown to the player BEFORE the run starts.
    Young-druide POV, 6-8 sentences, no 4th-wall break (simulation hidden)."""
    pool = INTRO_FRAGMENTS.get(archetype["id"], [])
    if not pool:
        return f"Tu es un jeune druide. Tu entres aujourd'hui dans Brocéliande pour vivre {archetype['name']}."
    return pool[variant_idx % len(pool)]


def make_twist(archetype, rng):
    """Mid-route revelation prose — recontextualizes the scenario.
    Returns a 2-3 sentence twist as a single string."""
    pool = TWIST_FRAGMENTS.get(archetype["id"], [])
    if not pool:
        return "Tu réalises une chose que tu n'avais pas vue. Le reste de la marche, désormais, prend un sens différent."
    return rng.choice(pool)


# Each route is identified by a 3-Pole alignment label.
ROUTE_LABELS = [
    {"key": "ordre",   "name": "Voie de l'Ordre",    "label": "Privilégie l'observation, la sagesse et la lignée."},
    {"key": "chaos",   "name": "Voie du Chaos",      "label": "Embrasse le risque, la confrontation et la ruse."},
    {"key": "liminal", "name": "Voie Liminale",      "label": "Cherche les passages, les seuils, l'entre-deux."},
]


def _branch_label_to_pole(route_key):
    return {"ordre": "Ordre", "chaos": "Chaos", "liminal": "Liminal"}.get(route_key, "Neutre")


def build_branching_tree(archetype, length, rng):
    """v7.7.22c — Split-merge tree :
       trunk (2) + branch1 (3×3=9) + twist (1) + branch2 (3×3=9) + final (length-9 shared)

    Returns flat card pool with card_id + route_mask per card, and options pointing
    to next card_id. Each of the 3 routes plays exactly `length` cards.
    """
    cards = []
    emotions = emotion_arc_for_length(archetype["emotion_arc"], length)
    em_idx = 0

    def next_emotion():
        nonlocal em_idx
        e = emotions[min(em_idx, len(emotions) - 1)]
        em_idx += 1
        return e

    # ── Phase 1 : Shared trunk (2 cards) ─────────────────────────────────────
    for i in range(2):
        n = len(cards) + 1
        card = make_card(n, length, archetype, next_emotion(), rng)
        card["card_id"] = f"c{n}"
        card["route_mask"] = [True, True, True]
        card["branch_label"] = "trunk"
        cards.append(card)

    # ── Phase 2 : First split (3 branches × 3 cards each) ────────────────────
    branch1_first_ids = {}  # route_key → first card_id of branch (target of choice)
    branch1_last_ids = {}   # route_key → last card_id of branch (links to twist)
    for r_idx, route in enumerate(ROUTE_LABELS):
        route_key = route["key"]
        for b_pos in range(3):  # 3 cards per branch
            n = len(cards) + 1
            # Build card biased toward the route's Pole.
            biased_archetype = dict(archetype)
            biased_archetype["pole"] = _branch_label_to_pole(route_key)
            card = make_card(n, length, biased_archetype, next_emotion(), rng)
            card["card_id"] = f"c{n}_{route_key}_b1_{b_pos}"
            card["route_mask"] = [r_idx == 0, r_idx == 1, r_idx == 2]
            card["branch_label"] = f"branch_1_{route_key}"
            if b_pos == 0:
                branch1_first_ids[route_key] = card["card_id"]
            if b_pos == 2:
                branch1_last_ids[route_key] = card["card_id"]
            cards.append(card)

    # ── Phase 3 : Merge + TWIST (1 shared card) ──────────────────────────────
    n = len(cards) + 1
    twist_card = make_card(n, length, archetype, "fascination", rng)
    twist_card["card_id"] = f"c{n}_twist"
    twist_card["route_mask"] = [True, True, True]
    twist_card["branch_label"] = "twist_merge"
    twist_card["type"] = "MERLIN_DIRECT"   # twist always Merlin Direct
    twist_card["rarity"] = "EPIQUE"
    # Replace summary with hand-crafted twist prose.
    twist_card["summary"] = make_twist(archetype, rng)
    twist_card["is_twist"] = True
    cards.append(twist_card)
    twist_card_id = twist_card["card_id"]

    # ── Phase 4 : Second split (3 branches × 3 cards each) ───────────────────
    branch2_first_ids = {}
    branch2_last_ids = {}
    for r_idx, route in enumerate(ROUTE_LABELS):
        route_key = route["key"]
        for b_pos in range(3):
            n = len(cards) + 1
            biased_archetype = dict(archetype)
            biased_archetype["pole"] = _branch_label_to_pole(route_key)
            card = make_card(n, length, biased_archetype, next_emotion(), rng)
            card["card_id"] = f"c{n}_{route_key}_b2_{b_pos}"
            card["route_mask"] = [r_idx == 0, r_idx == 1, r_idx == 2]
            card["branch_label"] = f"branch_2_{route_key}"
            if b_pos == 0:
                branch2_first_ids[route_key] = card["card_id"]
            if b_pos == 2:
                branch2_last_ids[route_key] = card["card_id"]
            cards.append(card)

    # ── Phase 5 : Final shared stretch (length - 9 shared cards) ────────────
    final_cards_count = max(2, length - 9)   # at least 2 shared closing cards
    final_first_id = None
    final_card_ids = []
    for i in range(final_cards_count):
        n = len(cards) + 1
        card = make_card(n, length, archetype, next_emotion(), rng)
        card["card_id"] = f"c{n}"
        card["route_mask"] = [True, True, True]
        card["branch_label"] = "final_shared"
        cards.append(card)
        final_card_ids.append(card["card_id"])
        if final_first_id is None:
            final_first_id = card["card_id"]

    # ── Wire options → leads_to_card_id ──────────────────────────────────────
    # Trunk card 0 (c1) : 3 options lead to branch1 starts.
    # Trunk card 1 (c2) : 3 options lead to branch1 starts (player picks branch).
    # Branch1 cards (positions 0-1) : linear within branch (next in same route).
    # Branch1 last (pos 2) : leads to twist.
    # Twist : 3 options lead to branch2 starts.
    # Branch2 cards (positions 0-1) : linear.
    # Branch2 last (pos 2) : leads to final[0].
    # Final cards : linear, last one → null (end).

    by_id = {c["card_id"]: c for c in cards}

    def set_options_target(card, targets):
        """Targets : list of 3 card_ids (one per option) or `None` for end."""
        for i, opt in enumerate(card["options"]):
            opt["leads_to_card_id"] = targets[i] if i < len(targets) else None

    # Trunk card 1 (c1) : linear → c2 (player passes through but feels guided).
    set_options_target(cards[0], [cards[1]["card_id"], cards[1]["card_id"], cards[1]["card_id"]])
    # Trunk card 2 (c2) : 3 options choose between Ordre/Chaos/Liminal branches.
    set_options_target(cards[1], [
        branch1_first_ids["ordre"],
        branch1_first_ids["chaos"],
        branch1_first_ids["liminal"],
    ])

    # Branch1 cards : linear within branch.
    for r_idx, route in enumerate(ROUTE_LABELS):
        route_key = route["key"]
        for b_pos in range(3):
            cid = f"c{2 + 1 + (3 * r_idx) + b_pos + 1}_{route_key}_b1_{b_pos}"
            # Find by card_id pattern (positions calculated above are approximate, use by_id lookup).
            # Actually the card_id was set with n=len(cards)+1 at build time, so use the cards list.
            pass
    # Simpler : iterate cards list, set links based on branch_label + position.
    for c in cards:
        bl = c.get("branch_label", "")
        if bl.startswith("branch_1_"):
            route_key = bl.replace("branch_1_", "")
            cid = c["card_id"]
            b_pos = int(cid.rsplit("_", 1)[-1])
            if b_pos < 2:
                # Find next branch1 card of same route.
                next_cid = next((d["card_id"] for d in cards
                                 if d.get("branch_label") == bl
                                 and int(d["card_id"].rsplit("_", 1)[-1]) == b_pos + 1), None)
                if next_cid:
                    set_options_target(c, [next_cid, next_cid, next_cid])
            else:
                # Last branch1 card → twist.
                set_options_target(c, [twist_card_id, twist_card_id, twist_card_id])

    # Twist card : 3 options choose between branch2 routes.
    set_options_target(twist_card, [
        branch2_first_ids["ordre"],
        branch2_first_ids["chaos"],
        branch2_first_ids["liminal"],
    ])

    # Branch2 cards : linear within branch, last → final_first.
    for c in cards:
        bl = c.get("branch_label", "")
        if bl.startswith("branch_2_"):
            route_key = bl.replace("branch_2_", "")
            cid = c["card_id"]
            b_pos = int(cid.rsplit("_", 1)[-1])
            if b_pos < 2:
                next_cid = next((d["card_id"] for d in cards
                                 if d.get("branch_label") == bl
                                 and int(d["card_id"].rsplit("_", 1)[-1]) == b_pos + 1), None)
                if next_cid:
                    set_options_target(c, [next_cid, next_cid, next_cid])
            else:
                # Last branch2 card → first final.
                set_options_target(c, [final_first_id, final_first_id, final_first_id])

    # Final cards : linear → next, last one → null.
    for i, fc_id in enumerate(final_card_ids):
        c = by_id[fc_id]
        if i < len(final_card_ids) - 1:
            nxt = final_card_ids[i + 1]
            set_options_target(c, [nxt, nxt, nxt])
        else:
            # Last card of scenario → END.
            set_options_target(c, [None, None, None])

    return cards, twist_card_id


def extract_routes(cards, twist_card_id):
    """v7.7.22c — Extract 3 actual routes (sequences of card_ids) from the tree.
    Each route follows the deterministic linear path of trunk→branch1→twist→branch2→final.
    """
    routes = []
    by_id = {c["card_id"]: c for c in cards}
    for r_idx, route in enumerate(ROUTE_LABELS):
        route_key = route["key"]
        card_ids = []
        # Trunk
        card_ids.extend(c["card_id"] for c in cards if c.get("branch_label") == "trunk")
        # Branch 1 (this route only)
        branch1 = sorted(
            (c for c in cards if c.get("branch_label") == f"branch_1_{route_key}"),
            key=lambda c: int(c["card_id"].rsplit("_", 1)[-1])
        )
        card_ids.extend(c["card_id"] for c in branch1)
        # Twist
        card_ids.append(twist_card_id)
        # Branch 2 (this route only)
        branch2 = sorted(
            (c for c in cards if c.get("branch_label") == f"branch_2_{route_key}"),
            key=lambda c: int(c["card_id"].rsplit("_", 1)[-1])
        )
        card_ids.extend(c["card_id"] for c in branch2)
        # Final shared stretch
        final = [c for c in cards if c.get("branch_label") == "final_shared"]
        card_ids.extend(c["card_id"] for c in final)
        routes.append({
            "key": route_key,
            "name": route["name"],
            "label": route["label"],
            "card_ids": card_ids,
        })
    return routes


def make_routes(cards):
    n = len(cards)
    if n <= 0:
        return []
    return [
        f"Voie de l'Ordre : carte 1 → choix « Observer » → carte {n // 3} « Honorer » → carte {2 * n // 3} « Méditer » → climax (acceptation)",
        f"Voie du Chaos : carte 1 → choix « Avancer » → carte {n // 3} « Affronter » → carte {2 * n // 3} « Tromper » → climax (rupture)",
        f"Voie Liminale : carte 1 → choix « Écouter » → carte {n // 3} « Franchir » → carte {2 * n // 3} « Apaiser » → climax (transformation)",
    ]


TITLES_PER_ARCHETYPE = {
    "druidic_awakening": [
        "Le Premier Pas Druidique", "Le Murmure de la Mousse", "L'Éveil sous le Hêtre",
        "La Forêt qui te Nomme", "Le Don du Silence", "Le Chêne te Parle",
        "Sept Pas Vers Toi-Même", "L'Initiation par la Brume", "La Clé sans Serrure",
        "Le Souffle des Druides",
    ],
    "korrigan_trickery": [
        "La Pomme qui Rit", "Trois Cailloux Blancs", "Le Pain Chaud sans Cause",
        "L'Enfant qui Flotte", "La Gourde Échangée", "Le Sentier qui se Plie",
        "La Marmite Vide", "Le Champignon-Champignon", "Les Pas qui Reviennent",
        "Le Rire dans les Fougères",
    ],
    "ancient_oak_counsel": [
        "Le Chêne aux Sept Cicatrices", "L'Écorce qui Parle", "La Visite du Vieillard de Bois",
        "Le Conseil sous la Couronne", "La Sève de Vérité", "L'Arbre qui Pleure",
        "Le Druide d'Écorce", "La Confession au Chêne", "Le Pacte sous la Mousse",
        "L'Enseignement du Tronc",
    ],
    "mist_wanderer": [
        "La Brume qui Souvient", "Trois Mois en Cinq Pas", "Le Brouillard aux Silhouettes",
        "La Lune Mauve", "Le Pommier hors Saison", "Les Îles d'Air Blanc",
        "Le Chemin qui se Mange", "L'Heure Suspendue", "Le Voyageur qui Dort Debout",
        "La Brume qui T'oublie",
    ],
    "forest_trial": [
        "La Gorge d'Épines", "Les Sangliers aux Yeux Rouges", "Le Froid Sans Soleil",
        "L'Épreuve des Ronces", "La Charge des Trois Bêtes", "Le Tunnel de Sang",
        "Le Mur Vivant", "La Tempête sans Vent", "Le Sentier qui Mord",
        "La Lèvre de la Bête",
    ],
    "forgotten_ritual": [
        "Le Septième Ogham", "Le Bol qui Manque", "L'Autel à l'If Noir",
        "Les Six Pierres et Toi", "La Cendre du Rite", "Le Crâne en Attente",
        "Le Cercle Imparfait", "L'Offrande sans Demande", "Le Geste Oublié",
        "L'Achèvement Silencieux",
    ],
    "hidden_sanctuary": [
        "La Clairière d'Or Pâle", "Le Ruisseau qui Guérit", "La Cabane Lierre",
        "Le Pain au Goût d'Enfance", "Le Cerf Sans Crainte", "Le Refuge Tiède",
        "La Mousse-Lit", "L'Eau qui Allège", "Le Repos Inattendu",
        "L'Hôte qui te Cède la Place",
    ],
    "beast_encounter": [
        "Le Cerf aux Os Accrochés", "La Louve aux Yeux Jaunes", "Le Sanglier-Mousse",
        "L'Ours-Roi", "Le Renard Blanc", "L'Aigle qui Parle",
        "La Bête Blessée", "Le Chant à la Bête", "Le Pacte du Sang",
        "La Marque du Museau",
    ],
    "druid_lineage": [
        "Ton Nom dans l'Écorce", "Les Quatre Druides Avant Toi", "La Stèle Inachevée",
        "Le Hêtre de Grand-Mère", "La Cape de Feuilles Cousues", "L'Héritage Refusé",
        "Le Druide qui te Ressemble", "La Lignée Brisée", "L'Inscription Future",
        "Le Sang qui se Souvient",
    ],
    "threshold_crossing": [
        "La Racine-Seuil", "La Porte Sans Cadre", "Le Voile de Feuilles Tremblantes",
        "L'Étang sans Eau", "L'Oiseau d'Or", "La Note Tenue",
        "L'Air qui Change de Poids", "Le Voyage en Deux Souffles", "Le Reflet qui Parle",
        "Le Seuil entre Deux Forêts",
    ],
}


def make_title(archetype, variant_idx):
    titles = TITLES_PER_ARCHETYPE.get(archetype["id"], [archetype["name"]])
    return titles[variant_idx % len(titles)]


def enforce_adjacency(cards, archetype, rng):
    """v7.7.22b — post-pass : demote any 2 consecutive SHOP / MERLIN_DIRECT /
    RUNE_UNLOCK / PROMISE to NARRATIVE COMMUNE (anti-fatigue per bible §28.2).
    Climax (last card) is preserved."""
    no_repeat = {"SHOP", "MERLIN_DIRECT", "RUNE_UNLOCK", "PROMISE"}
    n_total = len(cards)
    for i in range(1, n_total):
        if i == n_total - 1:
            continue   # never demote climax
        prev_t = cards[i - 1]["type"]
        curr_t = cards[i]["type"]
        if prev_t == curr_t and curr_t in no_repeat:
            cards[i]["type"] = "NARRATIVE"
            cards[i]["rarity"] = "COMMUNE"
            # Re-pick summary for the demoted card.
            pool = CARD_SUMMARY_TEMPLATES.get("NARRATIVE", {}).get(cards[i]["pole"], [])
            if not pool:
                pool = CARD_SUMMARY_TEMPLATES["NARRATIVE"]["Neutre"]
            cards[i]["summary"] = rng.choice(pool) if pool else cards[i]["summary"]
    return cards


def generate_scenario(archetype_idx, variant_idx):
    """v7.7.22c — generate a scenario with INTRO + BRANCHING TREE + REAL ROUTES.
    Each scenario now has 3 distinct routes (Ordre/Chaos/Liminal) sharing
    a trunk and final stretch but diverging on 2 branch phases."""
    archetype = ARCHETYPES[archetype_idx]
    seed = f"{archetype['id']}-{variant_idx}"
    rng = deterministic_rng(seed)
    length = rng.choice(archetype["length_pref"])
    title = make_title(archetype, variant_idx)
    emotions = emotion_arc_for_length(archetype["emotion_arc"], length)
    intro = make_intro(archetype, variant_idx)
    cards, twist_card_id = build_branching_tree(archetype, length, rng)
    cards = enforce_adjacency(cards, archetype, rng)
    routes = extract_routes(cards, twist_card_id)
    premise = make_premise(archetype, rng)
    # Total pool size (all cards in the tree) vs route length (cards a single route plays).
    pool_size = len(cards)
    return {
        "id": f"broc_{archetype_idx:02d}_{variant_idx:02d}",
        "title": title,
        "archetype_id": archetype["id"],
        "archetype_name": archetype["name"],
        "pole_dominant": archetype["pole"],
        "twist_pattern": archetype["twist_pattern"],
        "length": length,                  # cards a single route plays
        "pool_size": pool_size,            # total cards in the branching tree
        "emotional_arc": emotions,
        "intro": intro,                    # v7.7.22c — lore-aware contextualization
        "premise": premise,
        "essence": archetype["essence"],
        "hook": archetype["hook"],
        "twist_card_id": twist_card_id,
        "cards": cards,
        "routes": routes,                  # v7.7.22c — now {name,label,card_ids}
    }


def generate_all_scenarios():
    return [generate_scenario(a, v) for a in range(len(ARCHETYPES)) for v in range(10)]


# ═══════════════════════════════════════════════════════════════════════════════
# 5. HTML RENDERER — druidic dark theme matching MERLIN v7.7.22 UI charter
# ═══════════════════════════════════════════════════════════════════════════════

HTML_HEAD = """<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>M.E.R.L.I.N. — 100 Scénarios Brocéliande (v7.7.22)</title>
<style>
  :root {
    --gold:#eba84d; --gold-dim:#8c7a4b; --gold-bright:#ffd76b;
    --white:#f7f7f0; --black:#050505;
    --bg-dark:#0d0a08; --bg-panel:#1a1612; --bg-hover:#25201a;
    --crimson:#c72929; --violet:#9f62ff; --cyan:#5a8aa8;
    --ordre:#d4a868; --chaos:#9b59ff; --liminal:#5a8aa8; --neutre:#888;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg-dark);color:var(--white);font-family:'Georgia','Times New Roman',serif;line-height:1.65}
  header{background:linear-gradient(180deg,var(--bg-panel) 0%,var(--bg-dark) 100%);border-bottom:4px solid var(--gold);padding:36px 60px 24px;position:sticky;top:0;z-index:100}
  header h1{margin:0 0 6px;font-size:34px;color:var(--gold);letter-spacing:2px;text-transform:uppercase;text-shadow:0 0 18px rgba(235,168,77,.3)}
  header .subtitle{color:var(--gold-dim);font-style:italic;font-size:15px}
  header .stats{display:flex;gap:24px;margin-top:16px;flex-wrap:wrap}
  header .stat{background:var(--bg-dark);border:2px solid var(--gold-dim);padding:8px 14px;font-size:13px;color:var(--white)}
  header .stat strong{color:var(--gold-bright);font-size:17px;display:block;margin-bottom:2px}
  .filters{display:flex;gap:12px;flex-wrap:wrap;padding:14px 60px;background:var(--bg-panel);border-bottom:1px solid var(--gold-dim);align-items:center}
  .filters select,.filters input{background:var(--bg-dark);color:var(--white);border:2px solid var(--gold-dim);padding:6px 10px;font-family:inherit;font-size:14px}
  .filters select:focus,.filters input:focus{outline:none;border-color:var(--gold)}
  .filters label{color:var(--gold-dim);font-size:13px;margin-right:4px}
  .filters button{background:var(--bg-dark);border:2px solid var(--gold);padding:5px 14px;cursor:pointer;font-family:inherit;color:var(--gold);font-size:13px}
  .filters button:hover{background:var(--bg-hover)}
  main{padding:30px 60px;max-width:1500px;margin:0 auto}
  h2.archetype-heading{color:var(--gold);border-bottom:2px solid var(--gold-dim);padding-bottom:8px;margin-top:56px;font-size:26px}
  .scenario{border:3px solid var(--gold-dim);background:var(--bg-panel);margin-bottom:20px;overflow:hidden}
  .scenario.pole-Ordre{border-color:var(--ordre)}
  .scenario.pole-Chaos{border-color:var(--chaos)}
  .scenario.pole-Liminal{border-color:var(--liminal)}
  .scenario-header{background:var(--bg-dark);padding:14px 22px;border-bottom:1px solid var(--gold-dim);cursor:pointer;display:flex;justify-content:space-between;align-items:center;gap:18px}
  .scenario-header:hover{background:var(--bg-hover)}
  .scenario-title{color:var(--gold-bright);font-size:21px;margin:0;flex:1}
  .scenario-meta{display:flex;gap:8px;flex-wrap:wrap}
  .pole-badge{display:inline-block;padding:3px 10px;border:2px solid currentColor;font-size:12px;text-transform:uppercase;letter-spacing:1px;font-weight:bold}
  .pole-badge.Ordre{color:var(--ordre)}
  .pole-badge.Chaos{color:var(--chaos)}
  .pole-badge.Liminal{color:var(--liminal)}
  .pole-badge.Neutre{color:var(--neutre)}
  .length-badge{display:inline-block;padding:3px 10px;background:var(--bg-panel);border:1px dashed var(--gold-dim);font-size:12px;color:var(--white)}
  .scenario-body{padding:22px;display:none}
  .scenario.open .scenario-body{display:block}
  .essence{font-style:italic;color:var(--gold-dim);border-left:3px solid var(--gold);padding-left:14px;margin:0 0 18px}
  .hook{font-size:17px;color:var(--gold-bright);border:1px dashed var(--gold-dim);padding:12px 16px;margin:0 0 22px;background:var(--bg-dark)}
  .premise{white-space:pre-line;margin-bottom:22px;font-size:15.5px}
  .section-title{color:var(--gold);text-transform:uppercase;letter-spacing:2px;font-size:12px;margin:22px 0 10px;border-bottom:1px dotted var(--gold-dim);padding-bottom:4px}
  table.cards-table{width:100%;border-collapse:collapse;font-size:13px}
  table.cards-table th{background:var(--bg-dark);color:var(--gold);padding:8px 6px;text-align:left;border-bottom:2px solid var(--gold-dim);text-transform:uppercase;letter-spacing:1px;font-size:11px}
  table.cards-table td{padding:8px 6px;border-bottom:1px solid var(--bg-hover);vertical-align:top}
  table.cards-table tr:hover{background:var(--bg-hover)}
  td.n{color:var(--gold-bright);font-weight:bold;width:28px}
  td.summary{color:var(--white);font-style:italic;min-width:230px}
  td.options{font-size:12px;color:var(--gold-dim);min-width:200px}
  td.options ul{margin:0;padding-left:14px}
  td.options li{margin:2px 0}
  /* v7.7.22c — intro section + route view */
  .intro-block{background:linear-gradient(180deg,var(--bg-dark) 0%,var(--bg-panel) 100%);border-left:4px solid var(--gold-bright);padding:18px 22px;margin:0 0 22px;font-size:16.5px;line-height:1.75;color:var(--white);font-style:italic}
  .intro-block::before{content:"« ";color:var(--gold-bright);font-size:24px;font-style:normal}
  .intro-block::after{content:" »";color:var(--gold-bright);font-size:24px;font-style:normal}
  .routes-grid{display:grid;grid-template-columns:1fr 1fr 1fr;gap:14px;margin-top:18px}
  .route-col{background:var(--bg-dark);border:2px solid var(--gold-dim);padding:14px}
  .route-col.route-ordre{border-color:var(--ordre)}
  .route-col.route-chaos{border-color:var(--chaos)}
  .route-col.route-liminal{border-color:var(--liminal)}
  .route-col h4{margin:0 0 6px;color:var(--gold-bright);font-size:15px;text-transform:uppercase;letter-spacing:1px}
  .route-col h4.ordre{color:var(--ordre)}
  .route-col h4.chaos{color:var(--chaos)}
  .route-col h4.liminal{color:var(--liminal)}
  .route-col .route-desc{color:var(--gold-dim);font-style:italic;font-size:12px;margin:0 0 12px;border-bottom:1px dotted var(--gold-dim);padding-bottom:6px}
  .route-col ol{margin:0;padding-left:22px;font-size:12.5px;color:var(--white)}
  .route-col ol li{padding:5px 0;border-bottom:1px solid rgba(140,122,75,0.15)}
  .route-col ol li:last-child{border-bottom:none}
  .route-col .branch-tag{display:inline-block;font-size:9px;padding:1px 5px;border:1px solid currentColor;text-transform:uppercase;letter-spacing:0.5px;margin-left:4px;vertical-align:middle}
  .route-col .branch-tag.shared{color:var(--gold-dim)}
  .route-col .branch-tag.unique{color:var(--gold-bright)}
  .route-col .branch-tag.twist{color:var(--crimson);font-weight:bold}
  .route-col .card-text{display:block;font-size:11.5px;color:var(--gold-dim);margin-top:3px;font-style:italic;line-height:1.45}
  .pool-stats{display:flex;gap:18px;flex-wrap:wrap;margin:18px 0;padding:10px 14px;background:var(--bg-dark);border-left:3px solid var(--gold)}
  .pool-stats span{font-size:12px;color:var(--gold-dim)}
  .pool-stats strong{color:var(--gold-bright);font-size:14px}
  .twist-callout{margin:18px 0;padding:14px 18px;border:2px dashed var(--crimson);background:rgba(199,41,41,0.08);color:var(--white)}
  .twist-callout strong{color:var(--crimson);text-transform:uppercase;letter-spacing:1px;font-size:12px;display:block;margin-bottom:6px}
  /* End v7.7.22c additions */
  .rarity-COMMUNE{color:var(--gold-dim)}
  .rarity-RARE{color:var(--gold)}
  .rarity-EPIQUE{color:var(--violet);font-weight:bold}
  .rarity-LEGENDAIRE{color:var(--gold-bright);font-weight:bold;text-shadow:0 0 6px var(--gold)}
  .cardtype-NARRATIVE{color:var(--white)}
  .cardtype-EVENT{color:var(--cyan);font-weight:bold}
  .cardtype-SHOP{color:var(--ordre);font-weight:bold}
  .cardtype-MERLIN_DIRECT{color:var(--crimson);font-weight:bold}
  .cardtype-PROMISE{color:var(--violet)}
  .cardtype-RUNE_UNLOCK{color:var(--gold-bright);font-weight:bold}
  .routes{background:var(--bg-dark);border-left:3px solid var(--gold);padding:12px 16px;margin-top:18px}
  .routes li{list-style:none;padding:4px 0;color:var(--white);font-size:14px}
  .routes li::before{content:"▸ ";color:var(--gold);margin-right:4px}
  .toc{background:var(--bg-panel);border:2px solid var(--gold-dim);padding:18px 24px;margin-bottom:30px}
  .toc h2{margin-top:0;color:var(--gold)}
  .toc ul{list-style:none;padding-left:0;columns:2;column-gap:30px}
  .toc li{padding:3px 0;color:var(--white);font-size:14px}
  .toc a{color:var(--white);text-decoration:none}
  .toc a:hover{color:var(--gold-bright)}
  footer{padding:26px 60px;text-align:center;color:var(--gold-dim);font-size:12px;border-top:1px solid var(--gold-dim);margin-top:50px}
  .hidden{display:none!important}
</style>
</head>
<body>
"""

HTML_FOOTER = """
<footer>
  M.E.R.L.I.N. — 100 Scénarios Brocéliande — Généré le {timestamp}<br>
  Source : tools/generate_broceliande_scenarios.py (v7.7.22)<br>
  Bible canon : §3.2 (3 Poles) · §7.1 (biomes) · §28.1 (distribution)
</footer>
<script>
  document.querySelectorAll('.scenario-header').forEach(h => {
    h.addEventListener('click', () => h.parentElement.classList.toggle('open'));
  });
  const filterPole = document.getElementById('filter-pole');
  const filterLength = document.getElementById('filter-length');
  const filterArchetype = document.getElementById('filter-archetype');
  const filterSearch = document.getElementById('filter-search');
  function applyFilters() {
    const pole = filterPole.value, length = filterLength.value;
    const arch = filterArchetype.value, q = filterSearch.value.toLowerCase();
    document.querySelectorAll('.scenario').forEach(s => {
      const sp = s.dataset.pole, sl = s.dataset.length;
      const sa = s.dataset.archetype, st = s.textContent.toLowerCase();
      let ok = true;
      if (pole && sp !== pole) ok = false;
      if (length && sl !== length) ok = false;
      if (arch && sa !== arch) ok = false;
      if (q && !st.includes(q)) ok = false;
      s.classList.toggle('hidden', !ok);
    });
  }
  [filterPole, filterLength, filterArchetype, filterSearch].forEach(el => el.addEventListener('input', applyFilters));
  document.getElementById('expand-all').addEventListener('click', () => {
    document.querySelectorAll('.scenario:not(.hidden)').forEach(s => s.classList.add('open'));
  });
  document.getElementById('collapse-all').addEventListener('click', () => {
    document.querySelectorAll('.scenario').forEach(s => s.classList.remove('open'));
  });
</script>
</body>
</html>"""


def render_html(scenarios):
    import html as html_escape_module

    total = len(scenarios)
    by_pole = {}
    by_length = {}
    by_archetype = {}
    total_cards = 0
    for s in scenarios:
        by_pole[s["pole_dominant"]] = by_pole.get(s["pole_dominant"], 0) + 1
        by_length[s["length"]] = by_length.get(s["length"], 0) + 1
        by_archetype[s["archetype_name"]] = by_archetype.get(s["archetype_name"], 0) + 1
        total_cards += s["length"]

    parts = [HTML_HEAD]
    parts.append(f"""<header>
  <h1>M.E.R.L.I.N. — Brocéliande</h1>
  <div class="subtitle">100 scénarios de référence pour le LLM — biome Forêt de Brocéliande (Pôle Liminal dominant)</div>
  <div class="stats">
    <div class="stat"><strong>{total}</strong>scénarios</div>
    <div class="stat"><strong>{total_cards}</strong>cartes au total</div>
    <div class="stat"><strong>{len(ARCHETYPES)}</strong>archétypes narratifs</div>
    <div class="stat"><strong style="color:var(--liminal)">{by_pole.get('Liminal',0)}</strong>Liminal · <strong style="color:var(--chaos)">{by_pole.get('Chaos',0)}</strong>Chaos · <strong style="color:var(--ordre)">{by_pole.get('Ordre',0)}</strong>Ordre</div>
    <div class="stat">Longueurs : {' · '.join(f'<strong style=\"color:var(--gold-bright)\">{c}</strong>×{l}c' for l,c in sorted(by_length.items()))}</div>
  </div>
</header>""")

    arch_options = "\n".join(f'<option value="{a["id"]}">{a["name"]}</option>' for a in ARCHETYPES)
    parts.append(f"""<div class="filters">
  <label>Pole :</label>
  <select id="filter-pole"><option value="">Tous</option><option value="Liminal">Liminal</option><option value="Ordre">Ordre</option><option value="Chaos">Chaos</option></select>
  <label>Longueur :</label>
  <select id="filter-length"><option value="">Toutes</option><option value="11">11 cartes</option><option value="15">15 cartes</option><option value="17">17 cartes</option><option value="21">21 cartes</option><option value="25">25 cartes</option></select>
  <label>Archétype :</label>
  <select id="filter-archetype"><option value="">Tous</option>{arch_options}</select>
  <label>Recherche :</label>
  <input id="filter-search" type="text" placeholder="titre, mot-clé..." style="min-width:160px"/>
  <button id="expand-all">Tout déplier</button>
  <button id="collapse-all">Tout replier</button>
</div>""")
    parts.append("<main>")

    toc_items = []
    for archetype in ARCHETYPES:
        toc_items.append(f'<li><strong style="color:var(--gold);">{archetype["name"]}</strong> <span style="color:var(--gold-dim)">({by_archetype.get(archetype["name"], 0)} sc.)</span></li>')
        for s in scenarios:
            if s["archetype_id"] == archetype["id"]:
                toc_items.append(f'<li>&nbsp;&nbsp;<a href="#{s["id"]}">{s["title"]}</a> <span style="color:var(--gold-dim)">— {s["length"]} c.</span></li>')
    parts.append(f"""<div class="toc">
  <h2>Table des matières</h2>
  <ul>{''.join(toc_items)}</ul>
</div>""")

    for archetype in ARCHETYPES:
        arch_scenarios = [s for s in scenarios if s["archetype_id"] == archetype["id"]]
        if not arch_scenarios:
            continue
        parts.append(f'<h2 class="archetype-heading">{archetype["name"]} <span class="pole-badge {archetype["pole"]}">{archetype["pole"]}</span></h2>')
        parts.append(f'<p style="color:var(--gold-dim);font-style:italic;margin:6px 0 18px">{archetype["essence"]}</p>')

        for s in arch_scenarios:
            premise_html = html_escape_module.escape(s["premise"])
            intro_html = html_escape_module.escape(s.get("intro", ""))
            # ── v7.7.22c — Build 3-column route view ─────────────────────────
            by_id = {c["card_id"]: c for c in s["cards"]}
            twist_id = s.get("twist_card_id", "")
            route_columns = []
            for route in s["routes"]:
                route_key = route["key"]
                col_class = f"route-{route_key}"
                items = []
                for pos, cid in enumerate(route["card_ids"], 1):
                    c = by_id.get(cid)
                    if c is None:
                        continue
                    is_shared = all(c.get("route_mask", [True, True, True]))
                    is_twist = (cid == twist_id)
                    if is_twist:
                        badge = "<span class='branch-tag twist'>twist</span>"
                    elif is_shared:
                        badge = "<span class='branch-tag shared'>shared</span>"
                    else:
                        badge = "<span class='branch-tag unique'>unique</span>"
                    summary_short = html_escape_module.escape(c["summary"])
                    items.append(
                        f"<li><strong class='cardtype-{c['type']}'>{c['type'][:4]}</strong> "
                        f"<span class='rarity-{c['rarity']}'>·{c['rarity'][:3]}</span> "
                        f"<span class='pole-badge {c['pole']}' style='font-size:9px;padding:1px 5px;'>{c['pole'][:3]}</span>"
                        f"{badge}"
                        f"<span class='card-text'>{summary_short}</span></li>"
                    )
                route_columns.append(
                    f"<div class='route-col {col_class}'>"
                    f"<h4 class='{route_key}'>{html_escape_module.escape(route['name'])}</h4>"
                    f"<p class='route-desc'>{html_escape_module.escape(route['label'])} — <strong>{len(route['card_ids'])} cartes</strong></p>"
                    f"<ol>{''.join(items)}</ol>"
                    f"</div>"
                )
            routes_grid = f"<div class='routes-grid'>{''.join(route_columns)}</div>"

            # Twist callout (mid-route reveal).
            twist_text = ""
            if twist_id and twist_id in by_id:
                twist_card = by_id[twist_id]
                twist_text = (
                    f"<div class='twist-callout'>"
                    f"<strong>Rebondissement mi-parcours</strong>"
                    f"{html_escape_module.escape(twist_card['summary'])}"
                    f"</div>"
                )

            # Pool stats : show total pool vs cards-per-route.
            pool_size = s.get("pool_size", len(s["cards"]))
            pool_stats = (
                f"<div class='pool-stats'>"
                f"<span>Pool total : <strong>{pool_size}</strong> cartes</span>"
                f"<span>Cartes jouées par route : <strong>{s['length']}</strong></span>"
                f"<span>Cartes uniques à une route : <strong>{pool_size - s['length']}</strong></span>"
                f"<span>Routes possibles : <strong>{len(s['routes'])}</strong></span>"
                f"</div>"
            )

            parts.append(
                f"<article class='scenario pole-{s['pole_dominant']}' id='{s['id']}' "
                f"data-pole='{s['pole_dominant']}' data-length='{s['length']}' data-archetype='{s['archetype_id']}'>"
                f"<div class='scenario-header'>"
                f"<h3 class='scenario-title'>{s['title']}</h3>"
                f"<div class='scenario-meta'>"
                f"<span class='pole-badge {s['pole_dominant']}'>{s['pole_dominant']}</span>"
                f"<span class='length-badge'>{s['length']} cartes/route</span>"
                f"<span class='length-badge'>{pool_size} pool</span>"
                f"<span class='length-badge'>{s['twist_pattern']}</span>"
                f"</div></div>"
                f"<div class='scenario-body'>"
                f"<p class='essence'>{html_escape_module.escape(s['essence'])}</p>"
                f"<p class='hook'>« {html_escape_module.escape(s['hook'])} »</p>"
                f"<div class='section-title'>Intro — contextualisation joueur (jeune druide)</div>"
                f"<div class='intro-block'>{intro_html}</div>"
                f"<div class='section-title'>Prémisse narrative (vision de l'auteur)</div>"
                f"<div class='premise'>{premise_html}</div>"
                f"<div class='section-title'>Arc émotionnel ({s['length']} beats par route)</div>"
                f"<p style='color:var(--gold-dim);font-style:italic;'>{' → '.join(s['emotional_arc'])}</p>"
                f"{pool_stats}"
                f"{twist_text}"
                f"<div class='section-title'>Découpage en 3 routes — choix coupent / ouvrent les chemins</div>"
                f"<p style='color:var(--gold-dim);font-style:italic;font-size:13px;'>Le joueur ne joue pas toutes les cartes. À la carte 2 puis au rebondissement, son choix le branche sur une voie. Les cartes <em>shared</em> sont jouées par toutes les routes ; les <em>unique</em> ne se jouent que sur la voie correspondante.</p>"
                f"{routes_grid}"
                f"</div></article>"
            )

    parts.append("</main>")
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    # Use .replace() instead of .format() : HTML_FOOTER contains inline JS with
    # `{}` arrow-function braces that would conflict with str.format() parsing.
    parts.append(HTML_FOOTER.replace("{timestamp}", timestamp))
    return "".join(parts)


def main():
    scenarios = generate_all_scenarios()
    out_dir = Path.home() / "Downloads"
    out_dir.mkdir(parents=True, exist_ok=True)

    html_path = out_dir / "broceliande_scenarios_v7.7.22.html"
    json_path = out_dir / "broceliande_scenarios_v7.7.22.json"

    json_path.write_text(json.dumps(scenarios, ensure_ascii=False, indent=2), encoding="utf-8")
    html_path.write_text(render_html(scenarios), encoding="utf-8")

    total_cards = sum(s["length"] for s in scenarios)
    by_pole = {}
    by_length = {}
    for s in scenarios:
        by_pole[s["pole_dominant"]] = by_pole.get(s["pole_dominant"], 0) + 1
        by_length[s["length"]] = by_length.get(s["length"], 0) + 1

    print(f"[OK] Generated {len(scenarios)} scenarios, {total_cards} cards total")
    print(f"[OK] By Pole : {dict(sorted(by_pole.items()))}")
    print(f"[OK] By length : {dict(sorted(by_length.items()))}")
    print(f"[OK] HTML : {html_path}")
    print(f"[OK] JSON : {json_path}")
    print(f"[OK] HTML size : {html_path.stat().st_size / 1024:.1f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
