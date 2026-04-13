/**
 * NocoBase Deployment Automation for Dokploy
 * 
 * This script automates the deployment of NocoBase through Dokploy's web UI.
 * 
 * Prerequisites:
 *   npm install
 *   npx playwright install chromium
 * 
 * Usage:
 *   node deploy-nocobase.js
 * 
 * Or with Claude Code browser connection.
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
    dokployUrl: 'http://localhost:3000',
    projectName: 'nocobase',
    composeFile: path.join(__dirname, '..', 'compose-files', 'nocobase-compose.yml'),
    timeout: 300000, // 5 minutes for deployment
    headless: false, // Set to true for background execution
};

// Read compose file content
function getComposeContent() {
    return fs.readFileSync(CONFIG.composeFile, 'utf8');
}

async function deployNocoBase() {
    console.log('🚀 Starting NocoBase deployment automation...');
    
    const browser = await chromium.launch({ 
        headless: CONFIG.headless,
        slowMo: 100 // Slow down for visibility
    });
    
    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    try {
        // Step 1: Navigate to Dokploy
        console.log('📍 Navigating to Dokploy...');
        await page.goto(CONFIG.dokployUrl, { waitUntil: 'networkidle' });
        
        // Wait for dashboard to load
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
        
        // Fill project name
        const nameInput = page.locator('input[placeholder*="name" i], input[name="name"]').first();
        await nameInput.fill(CONFIG.projectName);
        
        // Click create button in modal
        await page.click('button:has-text("Create"):not(:has-text("Create Project"))');
        await page.waitForTimeout(2000);
        console.log('✅ Project created');
        
        // Step 4: Navigate into project (click on it)
        console.log('📂 Opening project...');
        await page.click(`text=${CONFIG.projectName}`);
        await page.waitForTimeout(1500);
        
        // Step 5: Create Compose service
        console.log('🐳 Creating Compose service...');
        await page.click('button:has-text("Create Service")');
        await page.waitForTimeout(1000);
        
        // Select Compose option
        await page.click('text=Compose');
        await page.waitForTimeout(2000);
        console.log('✅ Compose service created');
        
        // Step 6: Navigate to Compose tab and paste content
        console.log('📝 Configuring compose file...');
        
        // Look for the compose editor/textarea
        // Dokploy uses Monaco editor, so we need to find it
        const composeContent = getComposeContent();
        
        // Try to find the compose tab first
        const composeTab = page.locator('button:has-text("Compose"), [role="tab"]:has-text("Compose")');
        if (await composeTab.isVisible().catch(() => false)) {
            await composeTab.click();
            await page.waitForTimeout(1000);
        }
        
        // Find and fill the editor
        // Monaco editor approach
        const monacoEditor = page.locator('.monaco-editor textarea, .view-lines');
        if (await monacoEditor.isVisible().catch(() => false)) {
            await page.keyboard.press('Control+a');
            await page.keyboard.type(composeContent, { delay: 1 });
        } else {
            // Fallback to textarea
            const textarea = page.locator('textarea').first();
            await textarea.fill(composeContent);
        }
        
        console.log('✅ Compose content added');
        
        // Step 7: Save/Apply changes if needed
        const saveButton = page.locator('button:has-text("Save"), button:has-text("Apply")');
        if (await saveButton.isVisible().catch(() => false)) {
            await saveButton.click();
            await page.waitForTimeout(2000);
        }
        
        // Step 8: Deploy
        console.log('🚀 Starting deployment...');
        await page.click('button:has-text("Deploy")');
        
        // Wait for deployment to complete
        console.log('⏳ Waiting for deployment (this may take a few minutes)...');
        
        // Look for success indicators
        await page.waitForSelector('text=Running, text=running, text=Success', { 
            timeout: CONFIG.timeout 
        }).catch(() => {
            console.log('⚠️  Deployment status unclear, check Dokploy UI');
        });
        
        console.log('✅ Deployment initiated!');
        console.log('');
        console.log('🌐 NocoBase should be available at: http://localhost:13000');
        console.log('   (May take 1-2 minutes for first startup)');
        
        // Keep browser open for verification
        console.log('');
        console.log('Browser will close in 10 seconds...');
        await page.waitForTimeout(10000);
        
    } catch (error) {
        console.error('❌ Error during deployment:', error.message);
        console.log('');
        console.log('Manual steps if automation fails:');
        console.log('1. Open http://localhost:3000');
        console.log('2. Create Project → "nocobase"');
        console.log('3. Create Service → Compose');
        console.log('4. Paste compose file content');
        console.log('5. Click Deploy');
        
        // Take screenshot for debugging
        await page.screenshot({ path: 'error-screenshot.png' });
        console.log('Screenshot saved to error-screenshot.png');
    } finally {
        await browser.close();
    }
}

// Run
deployNocoBase().catch(console.error);
