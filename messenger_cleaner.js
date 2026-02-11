// ==UserScript==
// @name         Messenger Cleaner V16.0 (Sidebar Fix)
// @namespace    http://tampermonkey.net/
// @version      16.0
// @description  Blokuoja Shorts/Reels/TikTok ir paslepia VISĄ žinutės eilutę. Sidebar rodo naujausius pranešimus, jei jie nėra nuorodos.
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V16.0: Startuoja (Sidebar Fix)...");

    // --- 1. CSS INJEKCIJA ---
    // Paslepia konkrečias nuorodas iškart (prevencija)
    const style = document.createElement('style');
    style.innerHTML = `
        a[href*="tiktok.com"],
        a[href*="/reel/"],
        a[href*="/shorts/"],
        a[href*="fb.watch"],
        a[href*="/videos/"] {
            display: none !important;
        }

        /* Visiškai paslepiame elementą, kurį pažymėjo JS (eilutę arba žinutę) */
        [data-v16-cleaned="true"] {
            display: none !important;
        }
    `;
    document.head.appendChild(style);

    // --- 2. JS LOGIKA ---

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
        if (element.getAttribute('data-v16-cleaned') === 'true') return;

        // Pažymime elementą paslėpimui
        element.setAttribute('data-v16-cleaned', 'true');
        element.style.display = 'none';
    }

    function restoreElement(element) {
        if (!element) return;
        // Jei elementas buvo paslėptas, atstatome jį
        if (element.getAttribute('data-v16-cleaned') === 'true' || element.style.display === 'none') {
            element.removeAttribute('data-v16-cleaned');
            element.style.display = ''; // Panaikiname inline style
        }
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

    function getContainer(node) {
        // Bandome rasti visą eilutę (su avataru ir laiku)
        let row = node.closest('div[role="row"]');
        if (row) return row;

        let msgContainer = node.closest('div[data-testid="message-container"]');
        if (msgContainer) return msgContainer;

        if (node.tagName !== 'A' && node.tagName !== 'SPAN') {
             if (node.parentElement && node.parentElement.tagName === 'DIV') {
                 return node.parentElement;
             }
        }

        return node;
    }

    function checkSidebarItem(node) {
        const text = node.innerText || "";
        let isBad = false;

        // Tikriname domenus
        for (let domain of blockedDomains) {
             if (text.includes(domain)) {
                 isBad = true;
                 break;
             }
        }

        // Tikriname frazes
        if (!isBad) {
            for (let phrase of blockedPhrases) {
                if (text.toLowerCase().includes(phrase.toLowerCase())) {
                    isBad = true;
                    break;
                }
            }
        }

        // Sidebar atveju irgi bandome rasti visą elementą
        let container = node.closest('div[role="gridcell"]') || node.closest('div[data-testid="mwthreadlist-item"]');

        if (container) {
            if (isBad) {
                cleanElement(container);
            } else {
                // SVARBU: Jei tekstas geras (pvz., nauja žinutė), būtinai parodome elementą!
                restoreElement(container);
            }
        }
    }

    function cleanMess() {
        // 1. NUORODŲ VALYMAS (CHAT WINDOW - STRICT HIDE)
        const links = document.querySelectorAll('a:not([data-v16-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                let container = getContainer(link);
                cleanElement(container);
            }
            link.setAttribute('data-v16-processed', 'true');
        });

        // 2. SIDEBARO VALYMAS (DYNAMIC HIDE/RESTORE)
        // Nuimame :not([cleaned]) filtrą, kad nuolat tikrintume ar nepasikeitė tekstas (pvz., atėjo nauja žinutė)
        // Tai svarbu, kad "neberodo nieko" problema būtų išspręsta
        const potentialSidebarNodes = document.querySelectorAll('div[role="gridcell"] span, div[data-testid="mwthreadlist-item"] span');

        potentialSidebarNodes.forEach(node => {
            // Tikriname tik tuos spanus, kurie turi pakankamai teksto, kad būtų žinutė/preview
            if (node.innerText && node.innerText.length > 2) {
                checkSidebarItem(node);
            }
        });
    }

    // Naudojame debounce, kad per daug neapkrautume tikrinant sidebarą nuolat
    let debounceTimer = null;
    const observer = new MutationObserver((mutations) => {
        if (debounceTimer) clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            cleanMess();
        }, 100); // Trumpas debounce
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    cleanMess();

})();
