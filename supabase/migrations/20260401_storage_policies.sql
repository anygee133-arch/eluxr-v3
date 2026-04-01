-- Storage RLS policies for product-images bucket
-- Enables authenticated users to upload product images
-- Public read access for displaying images in UI

-- INSERT: Authenticated users upload to their own user_id/* path
CREATE POLICY "Users can upload product images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'product-images' 
    AND (auth.uid())::text = (storage.foldername(name))[1]
  );

-- SELECT: Public read (images displayed in UI, URLs are unguessable UUID paths)
CREATE POLICY "Public read product images" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'product-images');

-- UPDATE: Users can update their own product images
CREATE POLICY "Users can update own product images" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'product-images' 
    AND (auth.uid())::text = (storage.foldername(name))[1]
  );

-- DELETE: Users can delete their own product images
CREATE POLICY "Users can delete own product images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'product-images' 
    AND (auth.uid())::text = (storage.foldername(name))[1]
  );
