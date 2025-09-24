const readline = import('readline');

async function askQuestion(query: string): Promise<string> {
    const rl = await Promise.resolve((await readline).createInterface({
        input: process.stdin,
        output: process.stdout,
    }));

    const answer = await new Promise<string>((resolve) => {
        rl.question(query, resolve);
    });

    rl.close();

    return answer;
}

export async function confirmActionAsync(message: string, defaultValue: boolean | null = null, details: string | null = null): Promise<boolean> {
    if (details) {
        // Make sure that details has a single newline appended.
        details = details.trim() + '\n';
        console.log(details);
    }

    const defaultString = defaultValue === true ? 'y' : defaultValue === false ? 'n' : '';
    const appendDefault = defaultValue !== null ? ` [${defaultString}]` : '';
    const answer = (await askQuestion(`${message} (y / n)${appendDefault}: `)).toLowerCase();
    if (answer === '') {
        return defaultValue ?? false;
    } else if (answer === 'y' || answer === 'yes') {
        return true;
    } else if (answer === 'n' || answer === 'no') {
        return false;
    } else {
        console.log('Invalid input, please enter "y" or "n"');
        return confirmActionAsync(message, defaultValue);
    }
}