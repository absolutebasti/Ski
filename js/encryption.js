/**
 * KitzSki Tracker - Data Encryption
 * CRITICAL-012: Implement Data Encryption for Sensitive Storage
 * 
 * Provides client-side encryption for sensitive user data using
 * the Web Crypto API with AES-GCM encryption.
 */

const DataEncryption = {
    // Encryption constants
    ALGORITHM: 'AES-GCM',
    KEY_LENGTH: 256,
    IV_LENGTH: 12, // 96 bits for GCM
    SALT_LENGTH: 16,
    ITERATIONS: 100000,
    
    /**
     * Derive an encryption key from a password
     * @param {string} password - User password
     * @param {Uint8Array} salt - Salt for key derivation
     * @returns {Promise<CryptoKey>} Derived key
     */
    async deriveKey(password, salt) {
        const encoder = new TextEncoder();
        const passwordBuffer = encoder.encode(password);
        
        // Import password as key material
        const keyMaterial = await crypto.subtle.importKey(
            'raw',
            passwordBuffer,
            'PBKDF2',
            false,
            ['deriveBits', 'deriveKey']
        );
        
        // Derive AES-GCM key
        return crypto.subtle.deriveKey(
            {
                name: 'PBKDF2',
                salt: salt,
                iterations: this.ITERATIONS,
                hash: 'SHA-256'
            },
            keyMaterial,
            {
                name: this.ALGORITHM,
                length: this.KEY_LENGTH
            },
            false,
            ['encrypt', 'decrypt']
        );
    },
    
    /**
     * Generate a random salt
     * @returns {Uint8Array} Random salt
     */
    generateSalt() {
        return crypto.getRandomValues(new Uint8Array(this.SALT_LENGTH));
    },
    
    /**
     * Generate a random IV
     * @returns {Uint8Array} Random IV
     */
    generateIV() {
        return crypto.getRandomValues(new Uint8Array(this.IV_LENGTH));
    },
    
    /**
     * Encrypt data
     * @param {Object} data - Data to encrypt
     * @param {string} password - Encryption password
     * @returns {Promise<Object>} Encrypted data with salt and IV
     */
    async encrypt(data, password) {
        try {
            const salt = this.generateSalt();
            const iv = this.generateIV();
            const key = await this.deriveKey(password, salt);
            
            const encoder = new TextEncoder();
            const plaintext = encoder.encode(JSON.stringify(data));
            
            const ciphertext = await crypto.subtle.encrypt(
                {
                    name: this.ALGORITHM,
                    iv: iv
                },
                key,
                plaintext
            );
            
            return {
                version: 1,
                salt: Array.from(salt),
                iv: Array.from(iv),
                ciphertext: Array.from(new Uint8Array(ciphertext)),
                timestamp: Date.now()
            };
        } catch (error) {
            console.error('[Encryption] Encryption failed:', error);
            throw new Error('Failed to encrypt data');
        }
    },
    
    /**
     * Decrypt data
     * @param {Object} encryptedData - Encrypted data object
     * @param {string} password - Decryption password
     * @returns {Promise<Object>} Decrypted data
     */
    async decrypt(encryptedData, password) {
        try {
            const salt = new Uint8Array(encryptedData.salt);
            const iv = new Uint8Array(encryptedData.iv);
            const ciphertext = new Uint8Array(encryptedData.ciphertext);
            
            const key = await this.deriveKey(password, salt);
            
            const plaintext = await crypto.subtle.decrypt(
                {
                    name: this.ALGORITHM,
                    iv: iv
                },
                key,
                ciphertext
            );
            
            const decoder = new TextDecoder();
            return JSON.parse(decoder.decode(plaintext));
        } catch (error) {
            console.error('[Encryption] Decryption failed:', error);
            throw new Error('Failed to decrypt data - incorrect password or corrupted data');
        }
    },
    
    /**
     * Check if Web Crypto API is supported
     * @returns {boolean} True if supported
     */
    isSupported() {
        return typeof crypto !== 'undefined' && 
               typeof crypto.subtle !== 'undefined' &&
               typeof crypto.getRandomValues === 'function';
    },
    
    /**
     * Generate a secure random password
     * @param {number} length - Password length
     * @returns {string} Random password
     */
    generatePassword(length = 16) {
        const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
        const array = new Uint8Array(length);
        crypto.getRandomValues(array);
        
        let password = '';
        for (let i = 0; i < length; i++) {
            password += charset[array[i] % charset.length];
        }
        return password;
    },
    
    /**
     * Encrypt a run before storing
     * @param {Object} run - Run data
     * @param {string} password - Encryption password
     * @returns {Promise<Object>} Encrypted run
     */
    async encryptRun(run, password) {
        const encrypted = await this.encrypt(run, password);
        return {
            id: run.id,
            encrypted: true,
            data: encrypted
        };
    },
    
    /**
     * Decrypt a run after retrieving
     * @param {Object} encryptedRun - Encrypted run data
     * @param {string} password - Decryption password
     * @returns {Promise<Object>} Decrypted run
     */
    async decryptRun(encryptedRun, password) {
        if (!encryptedRun.encrypted) {
            return encryptedRun; // Not encrypted, return as-is
        }
        return this.decrypt(encryptedRun.data, password);
    }
};

// Make available globally
window.DataEncryption = DataEncryption;
