-- Migration: 0_init
-- Created by Prisma Migrate
-- Creates tables for book_tags, book_categories, reading_goals, book_queries

-- CreateTable: book_tags
CREATE TABLE "public"."book_tags" (
    "id" TEXT NOT NULL,
    "book_id" TEXT NOT NULL,
    "tag_name" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "book_tags_pkey" PRIMARY KEY ("id")
);

-- CreateIndex: book_tags_book_id_idx
CREATE INDEX "book_tags_book_id_idx" ON "public"."book_tags"("book_id");

-- CreateIndex: book_tags_tag_name_idx
CREATE INDEX "book_tags_tag_name_idx" ON "public"."book_tags"("tag_name");

-- CreateUniqueIndex: book_tags_book_id_tag_name_key
CREATE UNIQUE INDEX "book_tags_book_id_tag_name_key" ON "public"."book_tags"("book_id", "tag_name");

-- CreateTable: book_categories
CREATE TABLE "public"."book_categories" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "book_categories_pkey" PRIMARY KEY ("id")
);

-- CreateIndex: book_categories_name_key
CREATE UNIQUE INDEX "book_categories_name_key" ON "public"."book_categories"("name");

-- CreateIndex: book_categories_slug_key
CREATE UNIQUE INDEX "book_categories_slug_key" ON "public"."book_categories"("slug");

-- CreateTable: reading_goals
CREATE TABLE "public"."reading_goals" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "target_books" INTEGER NOT NULL,
    "period" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reading_goals_pkey" PRIMARY KEY ("id")
);

-- CreateIndex: reading_goals_user_id_idx
CREATE INDEX "reading_goals_user_id_idx" ON "public"."reading_goals"("user_id");

-- CreateIndex: reading_goals_user_id_year_idx
CREATE INDEX "reading_goals_user_id_year_idx" ON "public"."reading_goals"("user_id", "year");

-- CreateTable: book_quotes
CREATE TABLE "public"."book_quotes" (
    "id" TEXT NOT NULL,
    "book_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "page_number" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "book_quotes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex: book_quotes_book_id_idx
CREATE INDEX "book_quotes_book_id_idx" ON "public"."book_quotes"("book_id");

-- CreateIndex: book_quotes_user_id_idx
CREATE INDEX "book_quotes_user_id_idx" ON "public"."book_quotes"("user_id");