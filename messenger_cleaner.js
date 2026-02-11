// ==UserScript==
// @name         Messenger Cleaner V12.0 (CSS Instant Block)
// @namespace    http://tampermonkey.net/
// @version      12.0
// @description  Blokuoja Shorts/Reels akimirksniu (be mirgėjimo) ir rodo tuščią eilutę.
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V12.0: Startuoja (CSS Instant)...");

    // --- 1. CSS INJEKCIJA (Akimirksnio blokavimas) ---
    // Tai paslepia blogas nuorodas dar prieš užsikraunant JS logikai
    const style = document.createElement('style');
    style.innerHTML = `
        /* Paslepia konkrečias nuorodas pagal HREF */
        a[href*="tiktok.com"],
        a[href*="/reel/"],
        a[href*="/shorts/"],
        a[href*="fb.watch"],
        a[href*="/videos/"] {
            opacity: 0 !important;
            pointer-events: none !important;
            cursor: default !important;
            /* Ne display: none, kad išlaikytume vietą (tuščia eilutė) */
            visibility: hidden !important;
        }

        /* Jei norime visiškai paslėpti konteinerį, kurį JS pažymėjo */
        [data-v12-cleaned="true"] {
            visibility: hidden !important;
        }

        /* Padarome tuščią eilutę vietoje paslėpto turinio */
        [data-v12-cleaned="true"]::after {
            content: "";
            display: block;
            height: 20px;
            visibility: visible !important;
        }
    `;
    document.head.appendChild(style);


    // --- 2. JS LOGIKA (Papildomas valymas ir sekančių žinučių blokavimas) ---
    let spamProtectionUntil = 0;
    const SPAM_WINDOW_MS = 10000;
    let lastBadLinkElement = null;
    let debounceTimer = null;

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
        if (element.getAttribute('data-v12-cleaned') === 'true') return;

        // JS vis tiek reikalingas, kad sutvarkytų tėvinius elementus (konteinerius)
        // Bet CSS jau paslėpė patį linką, tad mirgėjimo nebus
        element.setAttribute('data-v12-cleaned', 'true');

        // Papildomai užtikriname stilių per JS (jei CSS nepakaktų)
        element.style.visibility = 'hidden';
        element.style.minHeight = '20px';
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

        // 1. NUORODŲ VALYMAS (Links)
        // Ieškome nuorodų
        const links = document.querySelectorAll('a:not([data-v12-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                spamProtectionUntil = Date.now() + SPAM_WINDOW_MS;

                // Bandome rasti visą žinutės "kortelę"
                let container = link.closest('div[dir="auto"]');
                if (!container) container = link.closest('.x1n2onr6');
                if (!container) container = link.parentElement;

                lastBadLinkElement = container || link;
                cleanElement(lastBadLinkElement);
            }
            link.setAttribute('data-v12-processed', 'true');
        });

        // 2. APSAUGA NUO SEKIMO (Next Message)
        if (isInSpamMode && lastBadLinkElement && lastBadLinkElement.isConnected) {
             const messageBubbles = document.querySelectorAll('div[dir="auto"]:not([data-v12-cleaned])');

             messageBubbles.forEach(msg => {
                 if (msg.innerText && msg.innerText.length > 0) {
                      if (lastBadLinkElement.compareDocumentPosition(msg) & Node.DOCUMENT_POSITION_FOLLOWING) {
                           cleanElement(msg);
                      }
                 }
             });
        }

        // 3. TEKSTO/SIDEBARO VALYMAS (Text Scanning)
        const potentialTextNodes = document.querySelectorAll('div[role="gridcell"] span:not([data-v12-cleaned]), div[data-testid="mwthreadlist-item"] span:not([data-v12-cleaned])');

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

    // Debounced Observer (Kad nestrigtų)
    // Tačiau pirmą kartą paleidžiame nedelsiant!
    const observer = new MutationObserver((mutations) => {
        // Greitas patikrinimas naujiems elementams (be debounce) - svarbu greičiui
        cleanMess();
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // Pirmas paleidimas
    cleanMess();

})();
