final initialScript = <String>[
  '''
CREATE TABLE users(
      id TEXT PRIMARY KEY,
      avatar TEXT,
      name TEXT,
      accountType TEXT,
      email TEXT,
      phone TEXT,
      isGmailIdUser INTEGER,
      isAppleIdUser INTEGER,
      createdAt TEXT,
      updatedAt TEXT,
      deletedAt TEXT
    )
  ''',
  '''
  CREATE TABLE user_details(
    id TEXT PRIMARY KEY,
    hasPassword INTEGER,
    hasPreferences INTEGER
    )
  ''',
  '''
 CREATE TABLE providers(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        logo TEXT,
        isActive INTEGER NOT NULL,
        description TEXT,
        rating REAL NOT NULL,
        reviews INTEGER NOT NULL,
        category TEXT,
        services TEXT NOT NULL,
        customerCareLine TEXT,
        phoneNumber TEXT,
        email TEXT,
        website TEXT,
        createdAt TIMESTAMP NOT NULL,
        updatedAt TIMESTAMP NOT NULL,
        deletedAt TIMESTAMP

)
''',
  '''
CREATE TABLE plans (
  -- Main plan fields
  id TEXT PRIMARY KEY,
  providerId TEXT,
  productId TEXT,
  name TEXT NOT NULL,
  description TEXT,
  rating INTEGER DEFAULT 0,
  reviews INTEGER DEFAULT 0,
  availabilityStatus TEXT,
  createdAt TIMESTAMP,
  updatedAt TIMESTAMP,
  deletedAt TIMESTAMP,

  -- Instance as JSON
  instance TEXT, -- Store as JSON string

  -- Provider as JSON
  Provider TEXT, -- Store as JSON string

  -- Product as JSON
  Product TEXT -- Store as JSON string
);

-- Create indices for better query performance
CREATE INDEX idx_plans_providerId ON plans(providerId);
CREATE INDEX idx_plans_productId ON plans(productId);
CREATE INDEX idx_plans_availabilityStatus ON plans(availabilityStatus);
'''
];

final migrationScript = <String>[];
