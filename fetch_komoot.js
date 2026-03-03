async function testKomoot() {
    try {
        const response = await fetch("https://api.komoot.de/v007/users/1/tours/", {
            method: 'GET',
            headers: {
                'Accept': 'application/hal+json'
            }
        });
        console.log("Status:", response.status);
        const data = await response.text();
        console.log("Data:", data);
    } catch (e) {
        console.error("Fetch failed:", e);
    }
}
testKomoot();
