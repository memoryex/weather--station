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

    // Kintamasis, saugantis laiką, iki kada blokuoti VISKĄ
    let spamProtectionUntil = 0;
    const SPAM_WINDOW_MS = 10000; // 10 sekundžių
    let lastBadLinkElement = null; // Saugome paskutinį blogą elementą, kad blokuotume tik po jo einančias žinutes

    // Frazės, kurias naikiname
    const blockedPhrases = [
        "Tadas atsiuntė priedą", "Mindaugas atsiuntė priedą",
        "Ramūnas atsiuntė priedą", "sent an attachment",
        "shared a reel", "pasidalijo ritiniu",
        "atsiuntė ritinį", "atsiuntė nuorodą", "sent a link"
    ];

    function isSafeNavigation(href) {
        if (!href) return true;
        if (href.includes('/messages/t/')) return true;
        if (href.includes('/t/')) return true;
        if (href.includes('/active_status/')) return true;
        if (href === '#' || href === '') return true;
        return false;
    }

    // Pagalbinė funkcija - PAKEISTI elementą į šluotelę
    function cleanElement(element, reason) {
        if (!element) return;

        // Jei jau išvalytas, nieko nedarom
        if (element.getAttribute('data-v11-cleaned') === 'true') return;

        // Išvalome turinį ir įdedame šluotelę
        // FIX: Naudojame template literals (backticks) vietoje JSX sintaksės
        element.innerHTML = `<span style="font-size:12px; color:#bbb; font-family: sans-serif;">🧹 ${reason}</span>`;

        // Stiliaus korekcijos, kad neužimtų daug vietos
        element.style.textDecoration = "none";
        element.style.pointerEvents = "none"; // Kad neitų paspausti
        element.style.display = "block";
        element.style.maxWidth = "200px";
        element.style.opacity = "0.7";

        // Pažymime, kad sutvarkyta
        element.setAttribute('data-v11-cleaned', 'true');
    }

    function cleanMess() {
        const currentTime = Date.now();
        const isInSpamMode = currentTime < spamProtectionUntil;

        // --- 1. NUORODŲ VALYMAS ---
        const links = document.querySelectorAll('a');

        links.forEach(link => {
            if (link.getAttribute('data-v11-processed') === 'true') return;

            const href = link.getAttribute('href');
            if (!href) return;

            let isBadLink = false;

            // --- TIKRINIMO LOGIKA ---
            if (href.includes('tiktok.com')) isBadLink = true;
            else if (href.includes('instagram.com') && href.includes('/reel/')) isBadLink = true;
            else if ((href.includes('youtube.com') || href.includes('youtu.be')) && href.includes('/shorts/')) isBadLink = true;
            else if ((href.includes('facebook.') || href.includes('fb.watch')) && !isSafeNavigation(href)) {
                if (href.includes('/reel/') || href.includes('fb.watch') || href.includes('/share/') || href.includes('/videos/')) {
                    isBadLink = true;
                }
            }

            if (isBadLink) {
                // 1. Aktyvuojame "Gynybos režimą" 10-čiai sekundžių
                spamProtectionUntil = Date.now() + SPAM_WINDOW_MS;

                // 2. Randame visą žinutės konteinerį
                let container = link.closest('div[dir="auto"]');
                if (!container) container = link.closest('.x1n2onr6');
                if (!container) container = link.parentElement;

                // Saugome nuorodą į konteinerį, kad žinotumėme poziciją
                lastBadLinkElement = container || link;

                cleanElement(lastBadLinkElement, "Spam Link");
            }

            link.setAttribute('data-v11-processed', 'true');
        });

        // --- 2. APSAUGA NUO SEKIMO (Grandininė reakcija) ---
        if (isInSpamMode && lastBadLinkElement) {
             // Ieškome visų žinutės "burbulų"
             const messageBubbles = document.querySelectorAll('div[dir="auto"], div[role="row"] span');

             messageBubbles.forEach(msg => {
                 if (msg.getAttribute('data-v11-cleaned') === 'true') return;

                 // Jei žinutė turi teksto ir atsirado blokavimo metu -> Valom
                 if (msg.innerText && msg.innerText.length > 0) {
                      // FIX: Tikriname ar žinutė yra PO blogos nuorodos (DOM struktūroje)
                      // Tai apsaugo nuo ankstesnių žinučių blokavimo scrollinant į viršų
                      if (lastBadLinkElement.compareDocumentPosition(msg) & Node.DOCUMENT_POSITION_FOLLOWING) {
                           cleanElement(msg, "Sekanti žinutė (10s)");
                      }
                 }
             });
        }

        // --- 3. FRAZIŲ VALYMAS ---
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
        let node;
        while (node = walker.nextNode()) {
            const text = node.nodeValue;
            for (let phrase of blockedPhrases) {
                if (text && text.toLowerCase().includes(phrase.toLowerCase())) {
                    if (node.parentElement && !node.parentElement.innerHTML.includes('🧹')) {
                         // FIX: Template literal
                         cleanElement(node.parentElement, `Frazė: ${phrase}`);
                    }
                }
            }
        }
    }

    // Stebėtojas
    const observer = new MutationObserver((mutations) => {
        cleanMess();
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    setInterval(cleanMess, 500);

})();
