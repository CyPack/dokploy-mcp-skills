/**
 * Twenty CRM Deployment Automation for Dokploy
 * 
 * This script automates the deployment of Twenty CRM through Dokploy's web UI.
 * 
 * Prerequisites:
 *   npm install
 *   npx playwright install chromium
 * 
 * Usage:
 *   node deploy-twenty.js
 * 
 * Note: Twenty requires more resources (~2GB RAM) and takes longer to start.
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
    dokployUrl: 'http://localhost:3000',
    projectName: 'twenty-crm',
    composeFile: path.join(__dirname, '..', 'compose-files', 'twenty-compose.yml'),
    timeout: 600000, // 10 minutes for deployment (Twenty is larger)
    headless: false,
};

function getComposeContent() {
    return fs.readFileSync(CONFIG.composeFile, 'utf8');
}

async function deployTwentyCRM() {
    console.log('🚀 Starting Twenty CRM deployment automation...');
    console.log('⚠️  Note: Twenty requires ~2GB RAM and takes longer to start');
    
    const browser = await chromium.launch({ 
        headless: CONFIG.headless,
        slowMo: 100
    });
    
    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    try {
        // Step 1: Navigate to Dokploy
        console.log('📍 Navigating to Dokploy...');
        await page.goto(CONFIG.dokployUrl, { waitUntil: 'networkidle' });
        await page.waitForSelector('text=Projects', { timeout: 10000 });
        console.log('✅ Dokploy dashboard loaded');
        
        // Step 2: Check if project already exists
        const existingProject = await page.locator(`text=${CONFIG.projectName}`).first();
        if (await existingProject.isVisible().catch(() => false)) {
            console.log(`⚠️  Project "${CONFIG.projectName}" already exists`);
            console.log('   Delete it manually or use a different name');
            await browser.close();
            return;
        }
        
        // Step 3: Create new project
        console.log('📁 Creating new project...');
        await page.click('button:has-text("Create Project")');
        await page.waitForSelector('input[placeholder*="name" i], input[name="name"]', { timeout: 5000 });
        
        const nameInput = page.locator('input[placeholder*="name" i], input[name="name"]').first();
        await nameInput.fill(CONFIG.projectName);
        
        await page.click('button:has-text("Create"):not(:has-text("Create Project"))');
        await page.waitForTimeout(2000);
        console.log('✅ Project created');
        
        // Step 4: Navigate into project
        console.log('📂 Opening project...');
        await page.click(`text=${CONFIG.projectName}`);
        await page.waitForTimeout(1500);
        
        // Step 5: Create Compose service
        console.log('🐳 Creating Compose service...');
        await page.click('button:has-text("Create Service")');
        await page.waitForTimeout(1000);
        
        await page.click('text=Compose');
        await page.waitForTimeout(2000);
        console.log('✅ Compose service created');
        
        // Step 6: Configure compose file
        console.log('📝 Configuring compose file...');
        const composeContent = getComposeContent();
        
        const composeTab = page.locator('button:has-text("Compose"), [role="tab"]:has-text("Compose")');
        if (await composeTab.isVisible().catch(() => false)) {
            await composeTab.click();
            await page.waitForTimeout(1000);
        }
        
        // Find and fill the editor
        const monacoEditor = page.locator('.monaco-editor textarea, .view-lines');
        if (await monacoEditor.isVisible().catch(() => false)) {
            await page.keyboard.press('Control+a');
            await page.keyboard.type(composeContent, { delay: 1 });
        } else {
            const textarea = page.locator('textarea').first();
            await textarea.fill(composeContent);
        }
        
        console.log('✅ Compose content added');
        
        // Step 7: Save if needed
        const saveButton = page.locator('button:has-text("Save"), button:has-text("Apply")');
        if (await saveButton.isVisible().catch(() => false)) {
            await saveButton.click();
            await page.waitForTimeout(2000);
        }
        
        // Step 8: Deploy
        console.log('🚀 Starting deployment...');
        await page.click('button:has-text("Deploy")');
        
        console.log('⏳ Waiting for deployment (Twenty takes 3-5 minutes)...');
        console.log('   Downloading images: twenty-server, twenty-postgres, redis');
        console.log('   Running database migrations...');
        
        await page.waitForSelector('text=Running, text=running, text=Success', { 
            timeout: CONFIG.timeout 
        }).catch(() => {
            console.log('⚠️  Deployment status unclear, check Dokploy UI');
        });
        
        console.log('✅ Deployment initiated!');
        console.log('');
        console.log('🌐 Twenty CRM should be available at: http://localhost:13001');
        console.log('   (First startup may take 2-3 minutes for migrations)');
        console.log('');
        console.log('📋 First run:');
        console.log('   1. Go to http://localhost:13001');
        console.log('   2. Create your admin account');
        console.log('   3. Start using the CRM');
        
        console.log('');
        console.log('Browser will close in 10 seconds...');
        await page.waitForTimeout(10000);
        
    } catch (error) {
        console.error('❌ Error during deployment:', error.message);
        console.log('');
        console.log('Manual steps if automation fails:');
        console.log('1. Open http://localhost:3000');
        console.log('2. Create Project → "twenty-crm"');
        console.log('3. Create Service → Compose');
        console.log('4. Paste compose file content');
        console.log('5. Click Deploy');
        
        await page.screenshot({ path: 'error-twenty-screenshot.png' });
        console.log('Screenshot saved to error-twenty-screenshot.png');
    } finally {
        await browser.close();
    }
}

// Run
deployTwentyCRM().catch(console.error);
