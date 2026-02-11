// ==UserScript==
// @name         Messenger Cleaner V13.0 (Fix Empty Bubbles)
// @namespace    http://tampermonkey.net/
// @version      13.0
// @description  Blokuoja Shorts/Reels akimirksniu ir rodo tik mažą tuščią eilutę (be didelio tarpo).
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V13.0: Startuoja (Compact Mode)...");

    // --- 1. CSS INJEKCIJA ---
    // Naudojame 'display: none' vietoje 'visibility: hidden', kad neliktų didelių tarpų.
    const style = document.createElement('style');
    style.innerHTML = `
        /* Paslepia konkrečias nuorodas visiškai (kad neužimtų vietos) */
        a[href*="tiktok.com"],
        a[href*="/reel/"],
        a[href*="/shorts/"],
        a[href*="fb.watch"],
        a[href*="/videos/"] {
            display: none !important;
        }

        /* Sutvarkome konteinerį, kurį pažymėjo JS */
        [data-v13-cleaned="true"] {
            display: block !important; /* Užtikriname, kad pats konteineris nedingtų */
            min-height: 24px !important; /* Minimalus aukštis "tuščiai eilutei" */
            height: auto !important;
            padding: 4px !important;
            overflow: hidden !important;
            color: transparent !important; /* Paslepiame tekstą */
        }

        /* Paslepiame visus vaikus konteinerio viduje, kad neliktų "didelių burbulų" */
        [data-v13-cleaned="true"] > * {
            display: none !important;
        }

        /* Sukuriame mažą "tarpą" (tuščią eilutę) */
        [data-v13-cleaned="true"]::after {
            content: " "; /* Tuščias tarpas */
            display: block;
            height: 100%;
            width: 100%;
        }
    `;
    document.head.appendChild(style);

    // --- 2. JS LOGIKA ---
    let spamProtectionUntil = 0;
    const SPAM_WINDOW_MS = 10000;
    let lastBadLinkElement = null;

    const blockedPhrases = [
        "Tadas atsiuntė priedą", "Mindaugas atsiuntė priedą",
        "Ramūnas atsiuntė priedą", "sent an attachment",
        "shared a reel", "pasidalijo ritiniu",
        "atsiuntė ritinį", "atsiuntė nuorodą", "sent a link"
    ];

    const blockedDomains = [
        "tiktok.com", "instagram.com/reel", "youtube.com/shorts", "youtu.be/shorts",
        "facebook.com/reel", "fb.watch", "facebook.com/share", "facebook.com/videos"
    ];

    function isSafeNavigation(href) {
        if (!href) return true;
        if (href.includes('/messages/t/')) return true;
        if (href.includes('/t/')) return true;
        if (href.includes('/active_status/')) return true;
        if (href === '#' || href === '') return true;
        return false;
    }

    function cleanElement(element) {
        if (!element) return;
        if (element.getAttribute('data-v13-cleaned') === 'true') return;

        // Pažymime elementą, kad CSS sutvarkytų jo išvaizdą (sutrauktų į mažą eilutę)
        element.setAttribute('data-v13-cleaned', 'true');

        // JS Fallback (jei CSS nesuveiktų dėl specifiškumo)
        // Išvalome vidų, kad neliktų didelių elementų (pvz., iframe ar image preview)
        // Tai svarbu, kad burbulas susitrauktų
        while (element.firstChild) {
            element.removeChild(element.firstChild);
        }
        element.innerHTML = '&nbsp;'; // Tuščia eilutė
    }

    function isBadUrl(url) {
        if (!url) return false;
        if (url.includes('tiktok.com')) return true;
        if (url.includes('instagram.com') && url.includes('/reel/')) return true;
        if ((url.includes('youtube.com') || url.includes('youtu.be')) && url.includes('/shorts/')) return true;
        if ((url.includes('facebook.') || url.includes('fb.watch')) && !isSafeNavigation(url)) {
            if (url.includes('/reel/') || url.includes('fb.watch') || url.includes('/share/') || url.includes('/videos/')) {
                return true;
            }
        }
        return false;
    }

    function cleanMess() {
        const currentTime = Date.now();
        const isInSpamMode = currentTime < spamProtectionUntil;

        // 1. NUORODŲ VALYMAS
        const links = document.querySelectorAll('a:not([data-v13-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                spamProtectionUntil = Date.now() + SPAM_WINDOW_MS;

                // Ieškome artimiausio logiško konteinerio
                let container = link.closest('div[dir="auto"]');
                if (!container) container = link.closest('.x1n2onr6');
                if (!container) container = link.parentElement;

                lastBadLinkElement = container || link;
                cleanElement(lastBadLinkElement);
            }
            link.setAttribute('data-v13-processed', 'true');
        });

        // 2. APSAUGA NUO SEKIMO
        if (isInSpamMode && lastBadLinkElement && lastBadLinkElement.isConnected) {
             const messageBubbles = document.querySelectorAll('div[dir="auto"]:not([data-v13-cleaned])');

             messageBubbles.forEach(msg => {
                 if (msg.innerText && msg.innerText.length > 0) {
                      if (lastBadLinkElement.compareDocumentPosition(msg) & Node.DOCUMENT_POSITION_FOLLOWING) {
                           cleanElement(msg);
                      }
                 }
             });
        }

        // 3. TEKSTO/SIDEBARO VALYMAS
        const potentialTextNodes = document.querySelectorAll('div[role="gridcell"] span:not([data-v13-cleaned]), div[data-testid="mwthreadlist-item"] span:not([data-v13-cleaned])');

        potentialTextNodes.forEach(node => {
            const text = node.innerText || "";
            let shouldClean = false;

            for (let domain of blockedDomains) {
                 if (text.includes(domain)) {
                     shouldClean = true;
                     break;
                 }
            }

            if (!shouldClean) {
                for (let phrase of blockedPhrases) {
                    if (text.toLowerCase().includes(phrase.toLowerCase())) {
                        shouldClean = true;
                        break;
                    }
                }
            }

            if (shouldClean) {
                 cleanElement(node);
            }
        });
    }

    const observer = new MutationObserver((mutations) => {
        cleanMess();
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    cleanMess();

})();
