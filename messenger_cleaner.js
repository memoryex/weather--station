// ==UserScript==
// @name         Messenger Cleaner V11.5 (Optimizuota + Tuščia Eilutė)
// @namespace    http://tampermonkey.net/
// @version      11.5
// @description  Blokuoja Shorts/Reels ir rodo tuščią eilutę. Optimizuotas veikimas be strigimo.
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V11.5: Startuoja (Optimizuota)...");

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
        if (element.getAttribute('data-v11-cleaned') === 'true') return;

        // Rodyti tuščią eilutę (kaip prašyta)
        // Išvalome vidų, bet paliekame elementą
        element.innerHTML = '&nbsp;';
        element.style.minHeight = '20px'; // Kad užimtų vietą (tuščia eilutė)
        element.style.color = 'transparent'; // Paslepiame bet kokį likusį tekstą

        // Pažymime
        element.setAttribute('data-v11-cleaned', 'true');
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
        // Ieškome tik neapdorotų nuorodų
        const links = document.querySelectorAll('a:not([data-v11-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                spamProtectionUntil = Date.now() + SPAM_WINDOW_MS;

                let container = link.closest('div[dir="auto"]');
                if (!container) container = link.closest('.x1n2onr6');
                if (!container) container = link.parentElement;

                lastBadLinkElement = container || link;
                cleanElement(lastBadLinkElement);
            }
            link.setAttribute('data-v11-processed', 'true');
        });

        // 2. APSAUGA NUO SEKIMO (Next Message)
        if (isInSpamMode && lastBadLinkElement && lastBadLinkElement.isConnected) {
             // Imame tik žinučių burbulus
             const messageBubbles = document.querySelectorAll('div[dir="auto"]:not([data-v11-cleaned])');

             messageBubbles.forEach(msg => {
                 if (msg.innerText && msg.innerText.length > 0) {
                      // Ar elementas yra žemiau nei bloga nuoroda?
                      if (lastBadLinkElement.compareDocumentPosition(msg) & Node.DOCUMENT_POSITION_FOLLOWING) {
                           cleanElement(msg);
                      }
                 }
             });
        }

        // 3. TEKSTO/SIDEBARO VALYMAS (Text Scanning)
        // Optimizuota: tikriname tik specifinius elementus, kur gali būti preview tekstas (Sidebar)
        // Nenaudojame 'checked' cache, nes sidebar tekstas gali pasikeisti (nauja žinutė)
        const potentialTextNodes = document.querySelectorAll('div[role="gridcell"] span:not([data-v11-cleaned]), div[data-testid="mwthreadlist-item"] span:not([data-v11-cleaned])');

        potentialTextNodes.forEach(node => {
            const text = node.innerText || "";
            let shouldClean = false;

            // Tikriname domenus tekste
            for (let domain of blockedDomains) {
                 if (text.includes(domain)) {
                     shouldClean = true;
                     break;
                 }
            }

            // Tikriname frazes
            if (!shouldClean) {
                for (let phrase of blockedPhrases) {
                    if (text.toLowerCase().includes(phrase.toLowerCase())) {
                        shouldClean = true;
                        break;
                    }
                }
            }

            if (shouldClean) {
                 // Sidebar atveju valome tik patį tekstinį elementą (preview), o ne visą kontaktą
                 cleanElement(node);
            }
        });
    }

    // Debounced Observer - Sprendžia "stringa" problemą
    const observer = new MutationObserver((mutations) => {
        if (debounceTimer) clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            cleanMess();
        }, 300); // Vykdoma tik kas 300ms, net jei daug pakeitimų
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // Pirmas paleidimas
    cleanMess();

})();
