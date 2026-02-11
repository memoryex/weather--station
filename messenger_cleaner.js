// ==UserScript==
// @name         Messenger Cleaner V11.0 (Su Šluotele 🧹)
// @namespace    http://tampermonkey.net/
// @version      11.0
// @description  Blokuoja Shorts/Reels ir pakeičia juos į 🧹. Taip pat blokuoja 10 sek. po jų einančias žinutes.
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V11.0: Startuoja su 🧹...");

    // Konfigūracija
    const SPAM_WINDOW_MS = 10000; // 10 sekundžių blokavimo langas

    // Frazės, kurias naikiname (papildoma apsauga)
    const blockedPhrases = [
        "Tadas atsiuntė priedą", "Mindaugas atsiuntė priedą",
        "Ramūnas atsiuntė priedą", "sent an attachment",
        "shared a reel", "pasidalijo ritiniu",
        "atsiuntė ritinį", "atsiuntė nuorodą", "sent a link"
    ];

    // Funkcija patikrinti, ar nuoroda yra "saugi" (vidinė navigacija)
    function isSafeNavigation(href) {
        if (!href) return true;
        // Vidiniai Messenger/Facebook keliai, kurių nereikia blokuoti
        if (href.includes('/messages/t/')) return true; // Pokalbio keitimas
        if (href.includes('/t/')) return true;
        if (href.includes('/active_status/')) return true;
        if (href.startsWith('#') || href === '') return true;
        if (href.includes('messenger.com') && !href.includes('l.messenger.com')) return true; // Pati svetainė, bet ne išorinės nuorodos
        return false;
    }

    // Pagalbinė funkcija - PAKEISTI elementą į šluotelę
    function cleanElement(element, reason) {
        if (!element) return;

        // Jei jau išvalytas, nieko nedarom
        if (element.getAttribute('data-v11-cleaned') === 'true') return;

        // Išvalome turinį ir įdedame šluotelę
        element.innerHTML = `<span style="font-size:12px; color:#bbb; font-family: sans-serif; user-select: none;">🧹 ${reason}</span>`;

        // Stiliaus korekcijos
        element.style.textDecoration = "none";
        // element.style.pointerEvents = "none"; // Galima palikti, jei norima visiškai uždrausti paspaudimą
        element.style.display = "block";
        element.style.maxWidth = "300px";
        element.style.opacity = "0.7";
        element.style.padding = "5px";

        // Pažymime, kad sutvarkyta ir KADA sutvarkyta (svarbu sekantiems pranešimams)
        element.setAttribute('data-v11-cleaned', 'true');
        element.setAttribute('data-v11-cleaned-time', Date.now().toString());
    }

    function cleanMess() {
        const currentTime = Date.now();

        // Bandome surasti visus pagrindinius žinučių blokus (eilutes)
        // x1n2onr6 dažnai būna žinutės konteineris
        let messageRows = document.querySelectorAll('div[role="row"], div[data-testid="message-container"], div.x1n2onr6');

        // Fallback: jei nerandame specifinių eilučių
        if (messageRows.length === 0) {
            messageRows = document.querySelectorAll('div[dir="auto"]');
        }

        // --- 1. NUORODŲ VALYMAS ---
        // Pirmiausia pereiname per visas nuorodas, kad identifikuotume "blogas"
        const links = document.querySelectorAll('a');
        links.forEach(link => {
            if (link.getAttribute('data-v11-processed') === 'true') return;

            const href = link.getAttribute('href');
            if (!href) return;

            let isBadLink = false;
            let reason = "";

            const lowerHref = href.toLowerCase();

            // --- TIKRINIMO LOGIKA ---

            // TikTok
            if (lowerHref.includes('tiktok.com')) {
                isBadLink = true;
                reason = "TikTok";
            }
            // Instagram Reels
            else if (lowerHref.includes('instagram.com') && lowerHref.includes('/reel/')) {
                isBadLink = true;
                reason = "Insta Reel";
            }
            // YouTube Shorts
            else if ((lowerHref.includes('youtube.com') || lowerHref.includes('youtu.be')) && lowerHref.includes('/shorts/')) {
                isBadLink = true;
                reason = "YT Shorts";
            }
            // Facebook (Reels, Watch, arba tiesiog FB nuorodos kurios nėra navigacija)
            else if ((lowerHref.includes('facebook.com') || lowerHref.includes('fb.watch')) && !isSafeNavigation(href)) {
                // Vartotojas prašė blokuoti "fb nuorodas".
                // Tai gali būti postai, video, reels.
                isBadLink = true;
                reason = "Facebook";
            }

            if (isBadLink) {
                // Randame visą žinutės konteinerį
                let container = link.closest('div[role="row"]'); // Bandome rasti visą eilutę
                if (!container) container = link.closest('.x1n2onr6');
                if (!container) container = link.closest('div[dir="auto"]');
                if (!container) container = link.parentElement;

                cleanElement(container || link, reason);
            }

            link.setAttribute('data-v11-processed', 'true');
        });

        // --- 2. APSAUGA NUO SEKIMO (Grandininė reakcija pagal DOM tvarką) ---
        // Iteruojame per visus žinučių konteinerius iš viršaus į apačią.
        // Jei randame "išvalytą" elementą, pažiūrime KADA jis išvalytas.
        // Jei jis išvalytas neseniai (< 10s), pratęsiame "blockUntil" laiką.
        // Visi sekantys elementai, kol currentTime < blockUntil, bus slepiami.

        let blockUntil = 0;

        // Atnaujiname sąrašą (nes cleanElement galėjo pakeisti struktūrą ar atributus)
        // Naudojame tą patį selektorių kaip viršuje
        const allRows = document.querySelectorAll('div[role="row"], div[data-testid="message-container"], div.x1n2onr6');

        if (allRows.length > 0) {
            allRows.forEach(row => {
                // Patikriname, ar šioje eilutėje yra "išvalytas" elementas (šluotelė)
                // Arba pati eilutė yra išvalyta
                const cleanedElement = row.querySelector('[data-v11-cleaned="true"]') || (row.getAttribute('data-v11-cleaned') === 'true' ? row : null);

                if (cleanedElement) {
                    // Jei tai buvo "bloga nuoroda" (ne "sekanti žinutė"), ji aktyvuoja blokavimą
                    // Patikriname innerText, kad atskirtume "Spam Link" nuo "Sekanti žinutė"
                    if (cleanedElement.innerText.includes('TikTok') ||
                        cleanedElement.innerText.includes('Facebook') ||
                        cleanedElement.innerText.includes('YT Shorts') ||
                        cleanedElement.innerText.includes('Insta Reel') ||
                        cleanedElement.innerText.includes('Spam Link')) {

                        const cleanedTime = parseInt(cleanedElement.getAttribute('data-v11-cleaned-time') || "0");
                        // Jei ši žinutė buvo išvalyta neseniai, ji blokuoja viską po savęs 10 sekundžių nuo savo pasirodymo
                        // Svarbu: cleanedTime + SPAM_WINDOW_MS
                        blockUntil = Math.max(blockUntil, cleanedTime + SPAM_WINDOW_MS);
                    }
                } else {
                    // Tai normali, neišvalyta žinutė.
                    if (currentTime < blockUntil) {
                        // Jei blokavimas aktyvus -> valome šitą žinutę
                        // Bet pirmiausia įsitikiname, kad joje yra teksto ar turinio
                        if (row.innerText && row.innerText.trim().length > 0) {
                             // Randame kur įterpti šluotelę (dažniausiai į vidų)
                             let textContainer = row.querySelector('div[dir="auto"]') || row;
                             cleanElement(textContainer, "Sekanti žinutė (10s)");
                        }
                    }
                }
            });
        }

        // --- 3. FRAZIŲ VALYMAS (Tekstinės šiukšlės) ---
        // Naudojame TreeWalker, kad rastume tekstinius node'us
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
        let node;
        while (node = walker.nextNode()) {
            const text = node.nodeValue;
            if (!text) continue;

            for (let phrase of blockedPhrases) {
                if (text.toLowerCase().includes(phrase.toLowerCase())) {
                    if (node.parentElement && !node.parentElement.innerHTML.includes('🧹')) {
                         cleanElement(node.parentElement, `Frazė: ${phrase}`);
                    }
                }
            }
        }
    }

    // Stebėtojas (MutationObserver)
    // Jis stebi DOM pasikeitimus ir paleidžia valymą
    const observer = new MutationObserver((mutations) => {
        cleanMess();
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // Taip pat paleidžiame intervalą, jei MutationObserver kažką praleistų
    setInterval(cleanMess, 1000);

})();
