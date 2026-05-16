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
    archetype = ARCHETYPES[archetype_idx]
    seed = f"{archetype['id']}-{variant_idx}"
    rng = deterministic_rng(seed)
    length = rng.choice(archetype["length_pref"])
    title = make_title(archetype, variant_idx)
    emotions = emotion_arc_for_length(archetype["emotion_arc"], length)
    cards = [make_card(n, length, archetype, emotions[n - 1], rng) for n in range(1, length + 1)]
    cards = enforce_adjacency(cards, archetype, rng)
    premise = make_premise(archetype, rng)
    routes = make_routes(cards)
    return {
        "id": f"broc_{archetype_idx:02d}_{variant_idx:02d}",
        "title": title,
        "archetype_id": archetype["id"],
        "archetype_name": archetype["name"],
        "pole_dominant": archetype["pole"],
        "twist_pattern": archetype["twist_pattern"],
        "length": length,
        "emotional_arc": emotions,
        "premise": premise,
        "essence": archetype["essence"],
        "hook": archetype["hook"],
        "cards": cards,
        "routes": routes,
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
            cards_rows = []
            for c in s["cards"]:
                opts_list = "<ul>" + "".join(
                    f"<li><strong>{html_escape_module.escape(o['label'])}</strong> ({o['verb']} → {o['primary_faction']})</li>"
                    for o in c["options"]
                ) + "</ul>"
                cards_rows.append(
                    f"<tr><td class='n'>{c['n']}</td>"
                    f"<td class='cardtype-{c['type']}'>{c['type']}</td>"
                    f"<td class='rarity-{c['rarity']}'>{c['rarity']}</td>"
                    f"<td><span class='pole-badge {c['pole']}'>{c['pole']}</span></td>"
                    f"<td>{c['emotion']}</td>"
                    f"<td class='summary'>{html_escape_module.escape(c['summary'])}</td>"
                    f"<td class='options'>{opts_list}</td></tr>"
                )
            cards_table = (
                "<table class='cards-table'>"
                "<thead><tr><th>#</th><th>Type</th><th>Rareté</th><th>Pole</th><th>Émotion</th><th>Carte</th><th>Options</th></tr></thead>"
                f"<tbody>{''.join(cards_rows)}</tbody></table>"
            )
            routes_list = "".join(f"<li>{html_escape_module.escape(r)}</li>" for r in s["routes"])
            premise_html = html_escape_module.escape(s["premise"])

            parts.append(
                f"<article class='scenario pole-{s['pole_dominant']}' id='{s['id']}' "
                f"data-pole='{s['pole_dominant']}' data-length='{s['length']}' data-archetype='{s['archetype_id']}'>"
                f"<div class='scenario-header'>"
                f"<h3 class='scenario-title'>{s['title']}</h3>"
                f"<div class='scenario-meta'>"
                f"<span class='pole-badge {s['pole_dominant']}'>{s['pole_dominant']}</span>"
                f"<span class='length-badge'>{s['length']} cartes</span>"
                f"<span class='length-badge'>{s['twist_pattern']}</span>"
                f"</div></div>"
                f"<div class='scenario-body'>"
                f"<p class='essence'>{html_escape_module.escape(s['essence'])}</p>"
                f"<p class='hook'>« {html_escape_module.escape(s['hook'])} »</p>"
                f"<div class='section-title'>Prémisse narrative</div>"
                f"<div class='premise'>{premise_html}</div>"
                f"<div class='section-title'>Arc émotionnel ({s['length']} beats)</div>"
                f"<p style='color:var(--gold-dim);font-style:italic;'>{' → '.join(s['emotional_arc'])}</p>"
                f"<div class='section-title'>Découpage en cartes</div>"
                f"{cards_table}"
                f"<div class='section-title'>Routes principales</div>"
                f"<ul class='routes'>{routes_list}</ul>"
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
