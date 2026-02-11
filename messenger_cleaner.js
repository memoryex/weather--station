// ==UserScript==
// @name         Messenger Cleaner V11.0 (Su Šluotele 🧹)
// @namespace    http://tampermonkey.net/
// @version      11.4
// @description  Blokuoja Shorts/Reels ir pakeičia juos į 🧹. Taip pat blokuoja 10 sek. po jų einančias žinutes.
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V11.4: Startuoja su tikslesniu valymu...");

    // 1. Įterpiame CSS stilių
    const style = document.createElement('style');
    style.innerHTML = `
        /* Paslepia patį elementą */
        .v11-cleaned {
            visibility: hidden !important;
        }

        /* Rodo "šluotelės" pranešimą */
        .v11-cleaned::after {
            content: '🧹 ' attr(data-v11-reason);
            visibility: visible !important;
            position: absolute !important;
            top: 0;
            left: 0;
            display: inline-block;
            color: #bbb;
            font-size: 11px;
            font-family: sans-serif;
            background: rgba(0,0,0,0.05);
            padding: 2px 5px;
            border-radius: 4px;
            white-space: nowrap;
            z-index: 10;
        }
    `;
    document.head.appendChild(style);


    // Konfigūracija
    const SPAM_WINDOW_MS = 10000; // 10 sekundžių blokavimo langas

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
        if (href.startsWith('#') || href === '') return true;
        if (href.includes('messenger.com') && !href.includes('l.messenger.com')) return true;
        return false;
    }

    // Apsaugos funkcija: ar elementas nėra per didelis (kad nepaslėptume viso puslapio)
    function isTooBig(element) {
        if (!element) return true;
        const rect = element.getBoundingClientRect();
        // Jei elementas užima daugiau nei pusę ekrano aukščio arba pločio - jis per didelis žinutei
        if (rect.height > window.innerHeight * 0.5) return true;
        if (rect.width > window.innerWidth * 0.8) return true;
        return false;
    }

    // Pagalbinė funkcija - PAKEISTI elementą į šluotelę (CSS būdu)
    function cleanElement(element, reason) {
        if (!element) return;

        // Jei jau išvalytas, nieko nedarom
        if (element.classList.contains('v11-cleaned')) return;

        // Apsauga nuo "viso ekrano" paslėpimo
        if (isTooBig(element)) {
            // Jei konteineris per didelis, bandome valyti patį linką, o ne konteinerį
            return;
        }

        element.setAttribute('data-v11-reason', reason);
        element.setAttribute('data-v11-cleaned-time', Date.now().toString());
        element.classList.add('v11-cleaned');
    }

    let isRunning = false;

    function cleanMess() {
        if (isRunning) return;
        isRunning = true;

        requestAnimationFrame(() => {
            try {
                processCleaning();
            } catch (e) {
                console.error("Messenger Cleaner Error:", e);
            } finally {
                isRunning = false;
            }
        });
    }

    function processCleaning() {
        // --- 1. RANDAME BLOGAS NUORODAS ---
        const links = document.querySelectorAll('a');
        links.forEach(link => {
            // Tikriname tik tas, kurios dar neapdorotos
            if (link.getAttribute('data-v11-processed') === 'true') return;

            const href = link.getAttribute('href');
            if (!href) return;

            let isBadLink = false;
            let reason = "";
            const lowerHref = href.toLowerCase();

            // --- TIKRINIMO LOGIKA ---
            if (lowerHref.includes('tiktok.com')) {
                isBadLink = true; reason = "TikTok";
            }
            else if (lowerHref.includes('instagram.com') && lowerHref.includes('/reel/')) {
                isBadLink = true; reason = "Insta Reel";
            }
            else if ((lowerHref.includes('youtube.com') || lowerHref.includes('youtu.be')) && lowerHref.includes('/shorts/')) {
                isBadLink = true; reason = "YT Shorts";
            }
            else if ((lowerHref.includes('facebook.com') || lowerHref.includes('fb.watch')) && !isSafeNavigation(href)) {
                isBadLink = true; reason = "Facebook";
            }

            if (isBadLink) {
                // Svarbu: pasirenkame tik artimiausią ŽINUTĖS eilutę
                // Messenger struktūra: div[role="row"] -> ... -> a
                let container = link.closest('div[role="row"]');

                // Jei nerandame role="row", bandome rasti žinutės burbulą (specifinės klasės)
                // x1n2onr6 dažnai naudojama žinutės eilutei
                if (!container) container = link.closest('.x1n2onr6');

                // Jei vis dar neradome, bandome div su dir="auto" (pats tekstas), bet tik jei jis tėvas
                if (!container) container = link.closest('div[dir="auto"]');

                // Jei nieko neradome arba elementas per didelis, valome patį linką (saugiausia)
                if (!container || isTooBig(container)) {
                    cleanElement(link, reason);
                } else {
                    cleanElement(container, reason);
                }
            }

            link.setAttribute('data-v11-processed', 'true');
        });

        // --- 2. APSAUGA NUO SEKIMO (Kaimynų principas) ---
        // Svarbu: iteruojame tik per role="row", nes jie garantuotai yra žinutės
        const rows = document.querySelectorAll('div[role="row"]');
        if (rows.length > 0) {
            for (let i = 0; i < rows.length; i++) {
                const row = rows[i];

                // Ar ši eilutė yra "išvalyta" (turi mūsų klasę)?
                // Arba jos VIDUJE yra išvalytas elementas (pvz. linkas)?
                const cleanedInside = row.querySelector('.v11-cleaned');
                const isRowCleaned = row.classList.contains('v11-cleaned');

                if (isRowCleaned || cleanedInside) {
                    // Randame priežastį
                    let reason = "";
                    if (isRowCleaned) reason = row.getAttribute('data-v11-reason') || "";
                    else if (cleanedInside) reason = cleanedInside.getAttribute('data-v11-reason') || "";

                    if (reason.includes('TikTok') || reason.includes('Facebook') || reason.includes('Shorts')) {

                        // Patikriname SEKANTĮ elementą (i + 1)
                        if (i + 1 < rows.length) {
                            const nextRow = rows[i + 1];

                            // Jei jis dar neišvalytas
                            if (!nextRow.classList.contains('v11-cleaned') && !nextRow.querySelector('.v11-cleaned')) {
                                cleanElement(nextRow, "Sekanti žinutė");
                            }
                        }
                    }
                }
            }
        }

        // --- 3. FRAZIŲ VALYMAS ---
        // Čia irgi atsargiau
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
        let node;
        while (node = walker.nextNode()) {
            const text = node.nodeValue;
            if (!text) continue;

            for (let phrase of blockedPhrases) {
                if (text.toLowerCase().includes(phrase.toLowerCase())) {
                    if (node.parentElement && !node.parentElement.classList.contains('v11-cleaned')) {
                        // Tikriname, ar nevalome viso puslapio
                        if (!isTooBig(node.parentElement)) {
                             cleanElement(node.parentElement, `Frazė: ${phrase}`);
                        }
                    }
                }
            }
        }
    }

    // Stebėtojas
    const observer = new MutationObserver((mutations) => {
        if (!isRunning) cleanMess();
    });

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
             observer.observe(document.body, { childList: true, subtree: true });
        });
    } else {
        observer.observe(document.body, { childList: true, subtree: true });
    }

    setInterval(cleanMess, 2000);

})();
